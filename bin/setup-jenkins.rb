gems = %w{trollop watir cucumber}
gems.each do |g|
  begin
    system("gem install #{g}")
    Gem.clear_paths
    puts "Installed #{g}"
  rescue LoadError
    puts "Couldn't install #{g}"
  end
end