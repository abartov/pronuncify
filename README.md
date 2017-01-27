# pronuncify - automate incrementally producing word pronunciation recordings for Wiktionary through Wikimedia Commons
##Version
Pronuncify is version 0.3, Jan 24th 2017
##Goal
Make it easy to quickly record batches of word pronunciations in [Ogg files](https://en.wikipedia.org/wiki/Ogg) suitable for upload to [Wikimedia Commons](https://commons.wikimedia.org) on any modern Linux machine.  

It does so using the command line, showing the user a word at a time and recording a 4-second file.  The user is then given a 4-second chance to reject it (if they made a mistake in recording, or if the word should not be recorded).  If the user does nothing, the next word is shown and recorded.  At the end of a run, you have `count` new Ogg files ready for upload, and named according to the standard in the [Pronunciation page](https://commons.wikimedia.org/wiki/Category:Pronunciation) on Commons.

A single-file database (using `SQLite`) is used to track which words have been recorded so far.

Currently, the script handles ingesting word lists, recording batches of word pronunciations, and uploading them to Wikimedia Commons.  The resultant Ogg files are deposited in a specified (or default) directory, and the user can either upload them to Commons manually, or employ the --upload option to have Pronuncify upload the files on their behalf.  Pronuncify will automatically assign the appropriate category on Commons, based on the language code.  

To upload, Pronuncify needs your Wikimedia username and password.  In the future, I may implement OAuth-based authentication.

##Prerequisites
* Ruby 2.x 
* the **sqlite3** library (`apt-get install sqlite3`) and gem (`gem install sqlite3`)
* the **mediawiki_api** gem (`gem install mediawiki_api`)
* the **iso-639** gem (`gem install iso-639`)
* **alsa-utils** (`apt-get install alsa-utils`)
* **sox** (`apt-get install sox`)
* your console needs to be able to render words in the chosen language (fonts matter!)

##Usage

###To ingest a wordlist
Given a UTF-8 plain text file with one word per line (lines beginning with '#' will be ignored), run:

 ```bash
 ruby pronuncify.rb --ingest <fname> --lang <ISO code> --db <database file>
 ```

**db** defaults to './pronuncify.db'

Example for a word-list in Hebrew with the default database: 
```bash
ruby pronuncify.rb --ingest wordlist.txt --lang he
```

###To prepare another batch for recording
Run: 

  ```bash
 ruby pronuncify.rb --count NN --lang <ISO code> --outdir <directory> --frequency <Hz> --device <devicename> --sample <format>
  ```
 
* **count** of words to record in a single run; defaults to 10
* **lang** not needed if only one language ingested so far
* **outdir** defaults to './pronounced_words_`ISO`'
* **frequency** defaults to 48000 Hz
* **device** will default to the system default.  If you have a USB microphone, though, you may want something like `--device hw:1,0` (see `arecord --list-devices`)
* **sample** will default to the system default.  If you have a USB microphone, you may need something like `--sample S16_LE`
 
so if you're only recording in one language and like the default count and output directory, you can just run: 
```bash
ruby pronuncify.rb 
```
to do 10 more words

###Upload recorded files to Commons
To upload the recorded words to Commons (moving them from the output directory to an /uploaded subdirectory), run:

  ```bash
   ruby pronuncify.rb --upload --user <username> --pass <password>
  ```
###Saved configuration
Pronuncify will read settings from a `pronuncify.yml` file if it exists.  You can still override specific settings by specifying them on the command line.  To create the file, run pronuncify with the settings you want and add the `--write-settings` option. 

Once you've saved your settings, you can just run 
```bash
ruby pronuncify.rb
```
to do another batch with your saved settings

##Contributing
To report issues or contribute to the code, see http://github.com/abartov/pronuncify

## See also
* [Pronuncify.net](https://github.com/abartov/pronuncify.net), a Windows GUI version of this tool.

## License
The code is in the public domain.  See the LICENSE file for details.
