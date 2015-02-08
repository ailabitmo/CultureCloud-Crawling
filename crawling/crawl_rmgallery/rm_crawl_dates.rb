require './rm_crawl_common'
require 'json'

@dates = Hash.new
get_artwork_ids.each do |object_id|
  Nokogiri::HTML(get_cached_artwork_page(object_id, :ru)).css('h2[align=center]').each do |html|
    date = html.text.split('.').last.strip
    @dates[object_id] = date
    # puts "#{object_id} #{date}"
  end
end

@templates = {
    :year                 => /^(?<year>\d{4}) ?(\(\d?\?\))?$/,
    :year_range           => /^(?<year_from>\d{4})[[–-]\/](?<year_to>\d{4}) ?(\(\?\))?$/,
    :year_between         => /^Между (?<year_from>\d{4}) и (?<year_to>\d{4}) ?(\(\?\))?$/,
    :year_about           => /^Около (?<year>\d{4})$/,
    :year_before          => /^До (?<year>\d{4})$/,
    :year_after           => /^После (?<year>\d{4})$/,
    :year_not_before      => /^Не ранее (?<year>\d{4})$/,
    :year_not_later       => /^Не позднее (?<year>\d{4})$/,
    :decade               => /^(?<decade>\d{4})-е$/,
    :decade_range         => /^(?<decade_from>\d{4})[-–](?<decade_to>\d{4})-е$/,
    :decade_begin         => /^Начало (?<decade>\d{4})-х$/,
    :decade_middle        => /^Середина (?<decade>\d{4})-[xх]$/,
    :decade_end           => /^Конец (?<decade>\d{4})-х$/,
    :decade_first_half    => /^Первая половина (?<decade>\d{4})-х$/,
    :decade_second_half   => /^Вторая половина (?<decade>\d{4})-х$/,
    :decade_end_begin     => /^Конец (?<decade_from>\d{4})(-х)? [–—] начало (?<decade_to>\d{4})-[хе]$/,
}

def range_single(year, comment_ru, comment_en)
  %W(#{year}-01-01 #{year}-12-31 #{comment_ru} #{comment_en})
  end
def range_single_decade(decade, comment_ru, comment_en)
  %W(#{decade}-01-01 #{(decade.to_i + 9).to_s}-12-31 #{comment_ru} #{comment_en})
end
def range_double(from, to, comment_ru, comment_en)
  %W(#{from}-01-01 #{to}-12-31 #{comment_ru} #{comment_en})
end
def range_double_decade(from, to, comment_ru, comment_en)
  %W(#{from}-01-01 #{to.to_i + 9}-12-31 #{comment_ru} #{comment_en})
end

@template_actions = {
    :year                 => lambda do |m|
      range_single(m[:year], m[:year], m[:year])
    end,
    :year_range           => lambda do |m|
      comment = "#{m[:year_from]}-#{m[:year_to]}"
      range_double(m[:year_from], m[:year_to], comment, comment)
    end,
    :year_between         => lambda do |m|
      comment_ru = "Между #{m[:year_from]} и #{m[:year_to]}"
      comment_en = "Between #{m[:year_from]} and #{m[:year_to]}"
      range_double(m[:year_from], m[:year_to], comment_ru, comment_en)
    end,
    :year_about           => lambda do |m|
      comment_ru = "Около #{m[:year]}"
      comment_en = "About #{m[:year]}"
      range_single(m[:year], comment_ru, comment_en)
    end,
    :year_before          => lambda do |m|
      comment_ru = "До #{m[:year]}"
      comment_en = "Before #{m[:year]}"
      range_single(m[:year], comment_ru, comment_en)
    end,
    :year_after           => lambda do |m|
      comment_ru = "После #{m[:year]}"
      comment_en = "After #{m[:year]}"
      range_single(m[:year], comment_ru, comment_en)
    end,
    :year_not_before      => lambda do |m|
      comment_ru = "Не ранее #{m[:year]}"
      comment_en = "Before #{m[:year]}"
      range_single(m[:year], comment_ru, comment_en)
    end,
    :year_not_later       => lambda do |m|
      comment_ru = "Не позднее #{m[:year]}"
      comment_en = "Not later than #{m[:year]}"
      range_single(m[:year], comment_ru, comment_en)
    end,
    :decade               => lambda do |m|
      comment_ru = "#{m[:decade]}-е (десятилетие)"
      comment_en = "#{m[:decade]}s (a decade)"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_range         => lambda do |m|
      comment_ru = "#{m[:decade_from]}-е — #{m[:decade_to]}-е"
      comment_en = "#{m[:decade_from]}s — #{m[:decade_to]}s"
      range_double(m[:decade_from], m[:decade_to], comment_ru, comment_en)
    end,
    :decade_begin         => lambda do |m|
      comment_ru = "Начало #{m[:decade]}-х"
      comment_en = "The beginning of#{m[:decade]}s"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_middle        => lambda do |m|
      comment_ru = "Середина #{m[:decade]}-х"
      comment_en = "Mid-#{m[:decade]}s"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_end           => lambda do |m|
      comment_ru = "Конец #{m[:decade]}-х"
      comment_en = "The end of the #{m[:decade]}s"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_first_half    => lambda do |m|
      comment_ru = "Первая половина #{m[:decade]}-х"
      comment_en = "First half of the #{m[:decade]}s"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_second_half   => lambda do |m|
      comment_ru = "Вторая половина #{m[:decade]}-х"
      comment_en = "Second half of the #{m[:decade]}s"
      range_single_decade(m[:decade], comment_ru, comment_en)
    end,
    :decade_end_begin     => lambda do |m|
      comment_ru = "Конец #{m[:decade_from]}-х — начало #{m[:decade_to]}-х"
      comment_en = "The beginning of the #{m[:decade_from]}s — the end of the #{m[:decade_to]}s"
      range_double_decade(m[:decade_from], m[:decade_to], comment_ru, comment_en)
    end,
}

@structured_dates = Hash.new
@unsolved = []

@dates.each do |object_id, date_str|
  @match = false
  @templates.each do |template_name, template|
    if template.match date_str
      @match = true
      # puts "#{object_id} #{template_name} | #{date_str}"
      @structured_dates[object_id] = @template_actions[template_name].(template.match(date_str))
      break
    end
  end
  @unsolved << date_str unless @match
end

puts "\nSolved: #{@dates.size - @unsolved.size}/#{@dates.size} " +
        "(#{(100 - @unsolved.size * 1.0 / @dates.size * 100.0).round(2)}%)"
puts "Unsolved:\n"
@unsolved.sort.each do |date_str|
  puts "  #{date_str}"
end

# File.open('dates_result.json', 'w') do |f|
#   f << JSON.pretty_generate(@structured_dates)
# end

puts "\nGenerating graph triples"
@graph = RDF::Graph.new(:format => :ttl)
@structured_dates.each do |object_id, date_struct|
  production_uri = RDF::URI.new("http://culturecloud.ru/resource/object/#{object_id}/production")
  time_span_uri = RDF::URI.new("http://culturecloud.ru/resource/object/#{object_id}/production/date")

  @graph << [production_uri, @ecrm['P4_has_time-span'], time_span_uri]
  @graph << [time_span_uri, RDF.type, @ecrm['E52_Time-Span']]
  @graph << [time_span_uri, RDF.type, OWL.NamedIndividual ]
  @graph << [time_span_uri, @ecrm[:P82a_begin_of_the_begin],
             RDF::Literal.new(date_struct[0], :datatype => RDF::XSD.date)]
  @graph << [time_span_uri, @ecrm[:P82b_end_of_the_end],
             RDF::Literal.new(date_struct[1], :datatype => RDF::XSD.date)]
  @graph << [time_span_uri, RDFS.label, RDF::Literal.new(date_struct[2], :language => "ru")]
  @graph << [time_span_uri, RDFS.label, RDF::Literal.new(date_struct[3], :language => "en")]
end

puts "Writing rm_artwork_dates.ttl\n"
File.open('rm_artwork_dates.ttl', 'w') do |f|
  f << @graph.dump(:ttl, :prefixes => @rdf_prefixes)
end