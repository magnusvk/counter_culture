class Article < ActiveRecord::Base
  belongs_to      :article_group, :foreign_key => :article_group_id
  counter_culture :article_group, :column_name => :articles_count

  attr_reader :title_en, :title_ja

  after_initialize do
    @title_en = title['en']
    @title_ja = title['ja']
    @custom_changes = {
      title_en: @title_en,
      title_ja: @title_ja
    }
  end

  def saved_changes
    hash = super()
    hash[:title_en] = [@custom_changes[:title_en], @title_en] if @custom_changes[:title_en] != @title_en
    hash[:title_ja] = [@custom_changes[:title_ja], @title_ja] if @custom_changes[:title_ja] != @title_ja
    hash
  end

  def title
    JSON.parse(super || "{}")
  end

  def title=(value)
    raise ArgumentError, "value must Hash" unless value.is_a?(Hash)
    super(value.to_json)

    @title_en = value['en']
    @title_ja = value['ja']
  end
end
