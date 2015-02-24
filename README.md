# rm-lod
Linked Data of the Russian Museum: data gathering tools
# About
This repository provides tools and utils (ruby scripts actually) to gather data for [Russian Museum Culture Cloud project](http://culturecloud.ru/) based on [FluidOps Informational WorkBench](https://www.fluidops.com/en/portfolio/information_workbench/) and [The CIDOC 
Conceptual Reference Model](http://www.cidoc-crm.org/)
Resulting datasets separeted to [CultureCloud-Datasets repositiry](https://github.com/ailabitmo/CultureCloud-Datasets)
# Repository structure
## crawling directory
Contains directories with ruby script for crawling data from the data sources (such as: [Russian Museum Gallery](http://rmgallery.ru) and [WikiArt](http://wikiart.org))
Common libraries stored into crawling dir.

Used 3rd party ruby libs:
- [Nokogiri](https://github.com/sparklemotion/nokogiri)
- [Ruby RDF](https://github.com/ruby-rdf)

## iwb-project
Archived [iwb](https://www.fluidops.com/en/portfolio/information_workbench/) xml import rules

## how to run current ruby scripts from windows:

Newest version have some problems building Nokogiri ruby gem from sources,
so I recommend to try Ruby 2.00:

- Download Ruby 2.0.0-p594 (x86 or x86_64) from: http://rubyinstaller.org/downloads/
- Install it, for, let's say: <code>C:\Ruby200\ </code>
- Download DEVELOPMENT KIT from the same webpage ( http://rubyinstaller.org/downloads/ ) for use with Ruby 2.0 and 2.1
- Extract Development Kit to some folder. Let's say, to "C:\Ruby200\devkit"

- Run commant promt cmd.exe (hotkey WIN+R)
- Change working dir to ruby path: <code>cd C:\Ruby200\ </code>
- Set ruby variables: <code>.\bin\setrbvars.bat </code>
- Set devkit variables: <code>.\devkit\devkitvars.bat </code>

- Install required Nokogiri gem: <code>gem install nokogiri </code>
- Install required colorize gem: <code>gem install colorize </code>
- Install required rdf-turtle gem: <code>gem install rdf-turtle </code>

- Clone rm-lod project to your local machine
- Change working dir to rmGalleryCrawler path: <code>cd C:\Ruby200\code\path\to\rm-lod\rmGalleryCrawler </code>
- Run ruby script: <code>ruby rmGalleryRDFBuilder.rb </code>
