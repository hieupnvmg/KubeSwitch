require 'yaml'
require 'json'

def read_config(path)
  raise 'File too large' if File.size(path) > 2_000_000
  data = YAML.safe_load(File.read(path), [], [], false)
  raise 'Invalid kubeconfig' unless data.is_a?(Hash) && data['contexts'].is_a?(Array) && data['clusters'].is_a?(Array)
  data
end

if ARGV[0] == 'scan'
  STDOUT.sync = true
  root = File.expand_path(ARGV[1])
  abort 'Invalid directory' unless File.directory?(root) && File.readable?(root)
  max_depth = Integer(ARGV[2] || '3')
  checked = 0
  skipped = 0
  found = 0
  last_progress = 0.0
  emit = lambda { |event| puts JSON.generate(event) }
  progress = lambda do |path, force = false|
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if force || now - last_progress >= 0.15
      emit.call(type: 'progress', checked: checked, skipped: skipped, found: found, path: path)
      last_progress = now
    end
  end
  excluded = %w[node_modules Library Applications vendor Pods .git .cache .npm .gradle]
  binary_extensions = %w[.png .jpg .jpeg .gif .webp .pdf .zip .gz .tar .dmg .mp4 .mp3 .mov .sqlite .db .woff .woff2 .ttf .icns .o .a .dylib .class .jar .pyc]
  queue = [[root, 0]]
  cursor = 0
  while cursor < queue.length
    directory, depth = queue[cursor]
    cursor += 1
    begin
      entries = Dir.children(directory).sort_by { |name| [name.match?(/kube|config|\.ya?ml$/i) ? 0 : 1, name] }
    rescue SystemCallError
      skipped += 1
      next
    end
    entries.each do |name|
      path = File.join(directory, name)
      progress.call(path)
      begin
        stat = File.lstat(path)
        if stat.symlink?
          skipped += 1
        elsif stat.directory?
          if (max_depth < 0 || depth < max_depth) && !excluded.include?(name) && (!name.start_with?('.') || name == '.kube')
            queue << [path, depth + 1]
          else
            skipped += 1
          end
        elsif stat.file?
          checked += 1
          if stat.size > 2_000_000 || binary_extensions.include?(File.extname(name).downcase) || name.include?('.kubeswitch-backup-')
            skipped += 1
            next
          end
          text = File.binread(path, 2_000_001)
          next if text.bytesize > 2_000_000
          next if text.include?("\x00") || !text.include?('contexts:') || !text.include?('clusters:')
          data = YAML.safe_load(text, [], [], false)
          next unless data.is_a?(Hash) && data['contexts'].is_a?(Array) && data['clusters'].is_a?(Array)
          contexts = data['contexts'].map { |c| c.is_a?(Hash) && c['name'].is_a?(String) ? c['name'] : nil }.compact
          next if contexts.empty?
          found += 1
          current = data['current-context'].is_a?(String) ? data['current-context'] : nil
          emit.call(type: 'config', config: {path: path, contexts: contexts, current: current})
        end
      rescue StandardError
        skipped += 1
      end
    end
  end
  progress.call(root, true)
  emit.call(type: 'done', checked: checked, skipped: skipped, found: found)
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
