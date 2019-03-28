def put_warnings(warnings, warnings_count)
  if warnings_count > 0
    warnings.sort_by!{|gem| gem["name"]}
    warn "\nThe following invoca gems in the gemfile are pointing behind the tips of their master branches."
    puts ""
    warnings.each do |gem|
      puts gem
      puts ""
    end
  end
end

lock = Bundler.read_file(Bundler.default_lockfile)
gems = Bundler::LockfileParser.new(lock)
incorrect_references = []
warnings = []
count = 0
warnings_count = 0
gems.sources.each do |source|
  begin
    if source.class == Bundler::Source::Git
      name = source.name
      sha = source.revision
      username = ENV['GITHUB_USERNAME']
      password = ENV['GITHUB_PASSWORD']
      repo_response = RestClient.get("https://#{username}:#{password}!@api.github.com/repos/Invoca/#{name}")
      forked = JSON.parse(repo_response)["fork"]
      next if forked
      response = RestClient.get("https://#{username}:#{password}!@api.github.com/repos/Invoca/#{name}/git/refs/heads/master")
      parsed = JSON.parse(response)
      master_sha = parsed["object"]["sha"]
      result = RestClient.get("https://#{username}:#{password}!@api.github.com/repos/Invoca/#{name}/compare/#{master_sha}...#{sha}")
      parsed = JSON.parse(result)
      ahead_by = parsed["ahead_by"]
      behind_by = parsed["behind_by"]
      if ahead_by > 0
        info = {"name" => name, "ahead_by" => ahead_by, "sha" => sha, "master sha" => master_sha}
        incorrect_references[count] = info
        count = count + 1
      else
        if behind_by > 0
          info = {"name" => name, "ahead_by" => ahead_by, "sha" => sha, "master sha" => master_sha}
          warnings[warnings_count] = info
          warnings_count = warnings_count + 1
        end
      end
    end
  rescue RestClient::Exception => ex
    puts name
    puts ex.http_body
  end
end

put_warnings(warnings, warnings_count)

if count > 0
  incorrect_references.sort_by!{|gem| gem["name"]}
  puts "\nThe shas of the following gems do not match the gem's masters"
  puts "Merge the gems into their respective master branches"
  puts ""
  incorrect_references.each do |gem|
    puts gem
    puts ""
  end
  exit(1)
else
  exit(0)
end
