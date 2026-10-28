require 'yaml'
require 'json'
require 'find'

def read_config(path)
  raise 'File too large' if File.size(path) > 2_000_000
  data = YAML.safe_load(File.read(path), [], [], false)
  raise 'Invalid kubeconfig' unless data.is_a?(Hash) && data['contexts'].is_a?(Array) && data['clusters'].is_a?(Array)
  data
end

if ARGV[0] == 'scan'
  found = []
  Find.find(ARGV[1]) do |path|
    if File.directory?(path)
      Find.prune if path != ARGV[1] && (File.basename(path).start_with?('.') && File.basename(path) != '.kube' || ['node_modules', 'Library', 'Applications'].include?(File.basename(path)))
      next
    end
    next unless File.file?(path) && !File.symlink?(path)
    begin
      next if File.size(path) > 2_000_000
      head = File.read(path, 8192)
      next unless head.include?('contexts:') && head.include?('clusters:')
      data = read_config(path)
      contexts = data['contexts'].map { |c| c['name'] }.select { |n| n.is_a?(String) }
      next if contexts.empty?
      found << {path: path, contexts: contexts, current: data['current-context']}
    rescue StandardError
      next
    end
  end
  puts JSON.generate(found.sort_by { |x| x[:path].downcase })
elsif ARGV[0] == 'build'
  path, context = ARGV[1], ARGV[2]
  data = read_config(path)
  raise 'Unknown context' unless data['contexts'].any? { |c| c['name'] == context }
  base = File.dirname(path)
  (data['clusters'] || []).each do |entry|
    cluster = entry['cluster'] || {}
    value = cluster['certificate-authority']
    cluster['certificate-authority'] = File.expand_path(value, base) if value.is_a?(String) && !value.empty?
  end
  (data['users'] || []).each do |entry|
    user = entry['user'] || {}
    ['client-certificate', 'client-key', 'tokenFile'].each do |key|
      value = user[key]
      user[key] = File.expand_path(value, base) if value.is_a?(String) && !value.empty?
    end
    command = user.dig('exec', 'command')
    if command.is_a?(String) && command.include?('/') && !command.start_with?('/')
      user['exec']['command'] = File.expand_path(command, base)
    end
  end
  data['current-context'] = context
  puts YAML.dump(data)
end
