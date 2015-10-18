# pronuncify - automate incrementally producing word pronunciation recordings for Wiktionary through Wikimedia Commons
##Goal
Make it easy to quickly record batches of word pronunciations in [Ogg files](https://en.wikipedia.org/wiki/Ogg) suitable for upload to [Wikimedia Commons](https://commons.wikimedia.org) on any modern Linux machine.

Currently, the script only handles ingesting word lists and recording batches of word pronunciations.  The resultant Ogg files are just deposited in a specified (or default) directory, and it is up to the user to upload them to Commons appropriately.  In the future, I may implement OAuth-based authentication so that the script would also be able to upload the files on your behalf.

##Prerequisites
* Ruby 2.x 
* the sqlite3 library (apt-get install sqlite3) and gem (gem install sqlite3)
* alsa-utils (apt-get install alsa-utils)
* sox (apt-get install sox)
* your console needs to be able to render words in the chosen language (fonts matter!)

##Usage

###To ingest a wordlist
Given a UTF-8 plain text file with one word per line (lines beginning with '#' will be ignored), run:

 ```bash
 ruby pronuncify.rb --ingest <fname> --lang <ISO code> --db <database file>
 ```

**db** defaults to './pronuncify.db'
Example for a word-list in Hebrew with the default database: ruby pronuncify.rb wordlist.txt he

###To prepare another batch for recording
Run: 

  ```bash
   ruby pronuncify.rb --count NN --lang <ISO code> --outdir <directory>
  ```
 
* **count** defaults to 20
* **lang** not needed if only one language ingested so far
* **outdir** defaults to './pronounced_words_<ISO code>'
 
so if you're only recording in one language and like the default count and output directory, you can just run: 
```bash
ruby pronuncify.rb 
```
to do 20 more words

To report issues or contribute to the code, see http://github.com/abartov/pronuncify

