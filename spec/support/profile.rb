RSpec.configure do |c|
  def profile
    result = RubyProf.profile { yield }
    name = example.metadata[:full_description].downcase.gsub(/[^a-z0-9_-]/, "-").gsub(/-+/, "-")
    printer = RubyProf::CallTreePrinter.new(result)
    p "profile method"
    open( ENGINE_RAILS_ROOT + "tmp/performance/callgrind.#{name}.#{Time.now.to_i}.trace", "w") do |f|
      printer.print(f)
    end
  end

  c.around(:each) do |example|
    if example.metadata[:profile]
      profile { example.run }
    else
      example.run
    end
  end
end
