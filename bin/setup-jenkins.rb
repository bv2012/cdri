gems = %w{trollop watir cucumber}
gems.each do |g|
  begin
    gem g
  rescue LoadError
    system("gem install #{g}")
    Gem.clear_paths
  end
end