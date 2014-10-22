# rmgallery.ru HTML data parser
# Alexey Andreyev: yetanotherandreyev@gmail.com
=begin
This software is licensed under the "Anyone But Richard M Stallman"
(ABRMS) license, described below. No other licenses may apply.


--------------------------------------------
The "Anyone But Richard M Stallman" license
--------------------------------------------

Do anything you want with this program, with the exceptions listed
below under "EXCEPTIONS".

THIS SOFTWARE IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND.

In the unlikely event that you happen to make a zillion bucks off of
this, then good for you; consider buying a homeless person a meal.


EXCEPTIONS
----------

Richard M Stallman (the guy behind GNU, etc.) may not make use of or
redistribute this program or any of its derivatives.

P.S.: just messing :)
=end

require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'uri'

def openHTML (url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 1
  http.read_timeout = 10
  begin
  response = http.get(uri.path)
  rescue Net::OpenTimeout
    puts "Catched new Net::OpenTimeout exception. Press return to retry (recommended) or Ctrl+C to interrupt (all data will be lost in that case)."
    gets
    retry
  end
  return response.body
end

# Russian and English rmgallery-IDs are the same

hostUrl = "http://rmgallery.ru/"
sectionsLabels = ["author","genre","type"] # TODO: "projects"-section with multiple images
BilingualLabel = Struct.new(:en, :ru)
localeLabels = BilingualLabel.new("en","ru")
annotationLabels = BilingualLabel.new("Аnnotation","Аннотация")
bioLabels = BilingualLabel.new("Author's Biogrphy","Биография автора") # typo consideration

artFile = File.open("rmgallery_art.xml","w")
artXML = Nokogiri::XML::Builder.new('encoding' => 'UTF-8') { |xml|
  xml.rmgallery {
    localeLabels.each { |localeLabel|
      puts "working with "+localeLabel+"-locale part:"
      xml.gallery('locale' => localeLabel) {
        sectionsLabels.each { |sectionLabel|
          puts "working with "+sectionLabel+"-"+localeLabel+"-section part:"
          xml.section('label' => sectionLabel) {
            sectionPage = Nokogiri::HTML(openHTML(hostUrl+localeLabel+"/"+sectionLabel))
            sectionCss = sectionPage.css("div[data-role='controlgroup']").css("a")
            sectionArraySize = sectionCss.size
            sectionArraySize.times { |idx|
              puts "section item: " + (idx+1).to_s + "/" + sectionArraySize.to_s
              sectionItemID = sectionCss[idx]["href"].scan(/\d/).join
              sectionItemLabel = sectionCss[idx].text  #TODO: clean from superfluous charactets
              xml.sectionItem('id' => sectionItemID, 'label' => sectionItemLabel) {
                artAuthorName = ""
                artAuthorBio = ""
                artItems = Nokogiri::HTML(openHTML(hostUrl+localeLabel+"/"+sectionItemID))
                artItemsCss = artItems.css("div[data-role='controlgroup']").css("a")
                artItemsTables = artItems.css("div[data-role='controlgroup']").css("table")
                artItemsArraySize = artItemsCss.size
                artItemsArraySize.times { |i|
                  puts "art item: " + (i+1).to_s + "/" + artItemsArraySize.to_s
                  artItemCss = artItemsCss[i]
                  artItemID = artItemCss["href"].scan(/\d/).join
                  rq = "img[src='http://www.virtualrm.spb.ru/compfiles2/files/small/"+artItemID+"_98.jpg']"
                  artItemImg = artItemsTables.css(rq)[0]
                  artItemLabel = ""
                  artItemAnnotation = ""
                  artItemDescription = ""

                  if (not artItemImg.nil?) then
                    artItemImgParentTr = artItemImg.parent.parent.parent # TODO: FIXME: shame on me
                    artAuthorName = artItemImgParentTr.css("small").text
                    artItemImgParentTr.css("small").remove
                    artItemLabel = artItemImgParentTr.text
                  else
                    artItemImg = artItemsCss.css(rq)[0]["title"]
                    artItemLabel = artItemImg
                  end
                  if ((artAuthorName.empty?) and (sectionLabel=="author")) then
                    artAuthorName = sectionItemLabel
                  end

                  artItemHTML = Nokogiri::HTML(openHTML(hostUrl+localeLabel+"/"+artItemID))
                  # TODO: check for more that 1 image per page (at projects pages)
                  imageUrl = artItemHTML.css("img[id='mainimg']")[0]["src"]
                  # alternative to previous string:
                  # xml.imageUrl "http://rmgallery.ru/files/medium/"+artItemID+"_98.jpg"
                  artItemDescriptionCss = artItemHTML.css("b").inner_html.split("<br>")
                  artItemDescriptionCss.shift
                  artItemDescription = artItemDescriptionCss.join(". ") # TODO: recognize particular strings meaning somehow
                  collapsibleInfos = artItemHTML.css("div[data-role='collapsible']")
                  collapsibleInfos.size.times { |n|
                    if (collapsibleInfos[n].css("h3").text == annotationLabels[localeLabel]) then
                      collapsibleInfos[n].css("h3").remove
                      artItemAnnotation = collapsibleInfos[n].text
                    end
                    if (artAuthorBio.empty?) then
                      if (collapsibleInfos[n].css("h3").text == bioLabels[localeLabel]) then
                        collapsibleInfos[n].css("h3").remove
                        collapsibleInfos[n].css("h2").remove
                        artAuthorBio = collapsibleInfos[n].text
                      end
                    end
                  }
                  xml.artItem('id' => artItemID, 'authorName' => artAuthorName, 'label' => artItemLabel) {
                    xml.description artItemDescription
                    xml.annotation artItemAnnotation
                    xml.imageUrl imageUrl
                  }
                }
                # here about author
                if (sectionLabel=="author") then
                  xml.bio artAuthorBio
                  xml.fullName artAuthorName
                end
              }
            }
          }
        }
      }
    }
  }
}

artFile.write(artXML.to_xml)
artFile.close
