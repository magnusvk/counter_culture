module YamlHelper
  def yaml_load(yaml)
    YAML.safe_load(yaml, permitted_classes: [Time])
  end
end

RSpec.configure do |config|
  config.include YamlHelper
end
