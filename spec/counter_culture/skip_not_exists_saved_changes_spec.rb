require 'spec_helper'

RSpec.describe "CounterCulture skip not exists attribute in saved_changes" do
  it "works with not exists attribute in saved_changes", :aggregate_failures do
    article_group = ArticleGroup.create(name: 'group1')

    article = Article.new
    article.article_group_id = article_group.id
    article.title = { 'en' => 'test1', 'ja' => 'テスト１' }
    article.save!

    article_group.reload
    expect(article_group.articles_count).to eq(1)

    article.title = { 'en' => 'test2', 'ja' => 'テスト１' }
    article.save!
    article_group.reload
    expect(article_group.articles_count).to eq(1)
  end
end
