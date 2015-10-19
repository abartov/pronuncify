#!/usr/bin/env ruby
#
# pronuncify - automate incrementally producing word pronunciation recordings for Wiktionary through Wikimedia Commons
#
# developed and maintained by Asaf Bartov <asaf.bartov@gmail.com>
#
# tested on Ruby 2.0.  

require 'rubygems'
require 'getoptlong'
#require 'mediawiki_api' # maybe one day, with OAuth
require 'sqlite3'
require 'timeout'
require 'io/console' # requires Ruby 2.0
#require 'byebug'

VERSION = "0.1 2015-10-17"
TODO = 1
DONE = 2
SKIP = 3
DEFAULT_OUTDIR = './pronounced_words_'
def usage
  puts <<-EOF
pronuncify - automate incrementally producing word pronunciation recordings for Wiktionary through Wikimedia Commons - version #{VERSION}

Prerequisites:
  - Ruby 2.x 
  - the sqlite3 library (apt-get install sqlite3) and gem (gem install sqlite3)
  - alsa-utils (apt-get install alsa-utils)
  - sox (apt-get install sox)

Usage: 

1. To ingest a wordlist, given a UTF-8 plain text file with one word per line (lines beginning with '#' will be ignored), run:

 ruby pronuncify.rb --ingest <fname> --lang <ISO code> --db <database file>
 db defaults to './pronuncify.db'
 Example for a word-list in Hebrew with the default database: ruby pronuncify.rb wordlist.txt he

2. To prepare another batch for recording, run: 

 ruby pronuncify.rb --count NN --lang <ISO code> --outdir <directory>
 
 count defaults to 20
 lang not needed if only one language ingested so far
 outdir defaults to './pronounced_words_<ISO code>'
 
 so if you're only recording in one language and like the default count and output directory, you can just run: ruby pronuncify.rb

To report issues or contribute to the code, see http://github.com/abartov/pronuncify
  EOF
  exit
end

def cfg_ok?(cfg)
  db = nil
  ret = true
  begin
    unless cfg[:list].nil?
      raise BadCfg if cfg[:lang].nil? # must specify language if ingesting
    else
      raise BadCfg unless File.exists?(cfg[:db]) 
      db = SQLite3::Database.new cfg[:db]
      lang_count = db.get_first_row("SELECT COUNT(DISTINCT lang) FROM words;")[0]
      if cfg[:lang].nil?
        raise BadCfg if lang_count > 1
        cfg[:lang] = db.get_first_row("SELECT lang FROM words;")[0] # only one lang in DB, so use it
      end
      cfg[:outdir] += cfg[:lang] if cfg[:outdir] == DEFAULT_OUTDIR # append language to outdir if not explicitly set
      `mkdir -p #{cfg[:outdir]}` unless Dir.exists?(cfg[:outdir]) # ensure outdir exists
    end
  rescue Exception => e
    ret = false
  ensure
    db.close unless db.nil?
  end
  return ret
end

def print_stats(db)
  db.results_as_hash = false
  word_count = db.execute("SELECT COUNT(id) FROM words")[0]
  todo_count = db.execute("SELECT COUNT(id) FROM words WHERE status = ?", TODO)[0]
  done_count = db.execute("SELECT COUNT(id) FROM words WHERE status = ?", DONE)[0]
  skip_count = db.execute("SELECT COUNT(id) FROM words WHERE status = ?", SKIP)[0]
  puts "of #{word_count} known words:\n  #{done_count} are done\n  #{todo_count} are still to-do\n  #{skip_count} were allocated previously but seem to have been skipped."
end
# main
cfg = { :list => nil, :outdir => DEFAULT_OUTDIR, :lang => nil, :db => './pronuncify.db', :count => 20 }

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--ingest', '-i', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--lang', '-l', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--db', '-d', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--count', '-c', GetoptLong::OPTIONAL_ARGUMENT],
  [ '--outdir', '-o', GetoptLong::OPTIONAL_ARGUMENT],
)

opts.each {|opt, arg|
  case opt
    when '--help'
      usage
    when '--ingest'
      cfg[:list] = arg
    when '--lang'
      cfg[:lang] = arg
    when '--db'
      cfg[:db] = arg
    when '--count'
      cfg[:count] = arg
    when '--outdir'
      cfg[:outdir] = arg
  end
}
usage unless cfg_ok?(cfg) # check args, print usage

db = SQLite3::Database.new cfg[:db]
unless cfg[:list].nil? # ingest mode
  table_exists = !(db.get_first_row("SELECT * FROM sqlite_master WHERE name = 'words' and type='table';").nil?)
  unless table_exists # initialize DB
    db.execute("CREATE TABLE words (id INTEGER PRIMARY KEY ASC, word varchar(255), status integer, lang varchar(10));")
    db.execute("CREATE INDEX words_by_lang_and_status on words (lang, status);")
  end
  abort("word-list file #{cfg[:list]} not found!") unless File.exists?(cfg[:list])
  puts "reading word-list..."
  list = File.open(cfg[:list], 'r:UTF-8').read.split.select {|l| l.strip[0] != '#'}  # slurp the word-list, ignoring comment lines
  puts "#{list.count} words read.  Inserting into database..."
  list.each {|word|
    res = nil
    begin
      res = db.execute("SELECT id FROM words WHERE word = ?", word)[0]
    rescue
    end
    if res.nil?
      db.execute("INSERT INTO words VALUES (NULL, ?, #{TODO}, '#{cfg[:lang]}')", word) 
    else
      puts "#{word} already in database; skipping."
    end
  }
else # make-progress mode
  puts "preparing a batch of #{cfg[:count]} words..."
  db.results_as_hash = true
  i = 1
  db.execute("SELECT id, word FROM words WHERE status = ? LIMIT ?", TODO, cfg[:count]) do |row|
    # record a brief audio
    filename = cfg[:outdir]+'/'+cfg[:lang]+'-'+row['word'].gsub('"','_').gsub("'",'_')
    puts "\npronounce -=[ #{row['word']} ]=-   progress: [#{i}/#{cfg[:count]}]"
    `arecord -r 100000 -d 4 #{filename}.wav`
    # give user a chance to cancel/skip the word
    begin
      puts "...press any key to SCRAP that word and skip it..."
      Timeout.timeout(4) do
        c = STDIN.getch
        # user pressed a key, meaning cancel/skip the recording
        exit(1) if c == "\u0003" # but exit entirely if CTRL+C was pressed
        db.execute("UPDATE words SET status = ? WHERE id = ?", SKIP, row['id']) # update DB
        puts "==> skipped!"
      end
    rescue Timeout::Error
      # time out means go ahead and process the recording
      `sox #{filename}.wav #{filename}.ogg norm vad -p .25 reverse vad -p .25 reverse` # convert to OGG, remove silence
      db.execute("UPDATE words SET status = ? WHERE id = ?", DONE, row['id']) # update DB
      puts "==> saved! :)"
    end 
    File.delete(filename+'.wav') # delete the recorded WAV file in any case
    i += 1
  end
end
# finalize DB, report results
print_stats(db)
db.close
puts "pronuncify done!"
exit 0

