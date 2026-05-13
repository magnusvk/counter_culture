require 'spec_helper'

RSpec.describe "CounterCulture when using discard for soft deletes" do
  it "works" do
    company = Company.create!
    expect(company.soft_delete_discards_count).to eq(0)
    sd = SoftDeleteDiscard.create!(company_id: company.id)
    expect(company.reload.soft_delete_discards_count).to eq(1)

    sd.discard
    sd.reload
    expect(sd).to be_discarded
    expect(company.reload.soft_delete_discards_count).to eq(0)

    company.update(soft_delete_discards_count: 100)
    expect(company.reload.soft_delete_discards_count).to eq(100)
    SoftDeleteDiscard.counter_culture_fix_counts
    expect(company.reload.soft_delete_discards_count).to eq(0)

    sd.undiscard
    expect(company.reload.soft_delete_discards_count).to eq(1)
  end

  it "runs destroy callback only once" do

    company = Company.create!
    sd = SoftDeleteDiscard.create!(company_id: company.id)

    expect(company.reload.soft_delete_discards_count).to eq(1)

    sd.discard
    expect(company.reload.soft_delete_discards_count).to eq(0)

    sd.discard
    expect(company.reload.soft_delete_discards_count).to eq(0)
  end

  it "runs restore callback only once" do
    company = Company.create!
    sd = SoftDeleteDiscard.create!(company_id: company.id)

    expect(company.reload.soft_delete_discards_count).to eq(1)

    sd.discard
    expect(company.reload.soft_delete_discards_count).to eq(0)

    sd.undiscard
    expect(company.reload.soft_delete_discards_count).to eq(1)

    sd.undiscard
    expect(company.reload.soft_delete_discards_count).to eq(1)
  end

  describe "when calling hard-destroy" do
    it "does not run destroy callback for discarded records" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.destroy
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end

    it "runs destroy callback for undiscarded records" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end
  end

  describe "dynamic column names with totaling instead of counting" do
    describe 'when updating discarded records' do
      it 'does not update sum' do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id, value: 5)

        expect(company.reload.soft_delete_discard_values_sum).to eq(5)

        sd.discard
        expect(company.reload.soft_delete_discard_values_sum).to eq(0)

        sd.update value: 10
        expect(company.reload.soft_delete_discard_values_sum).to eq(0)
      end
    end

    describe 'when updating undiscarded records' do
      it 'updates sum' do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id, value: 5)

        expect(company.reload.soft_delete_discard_values_sum).to eq(5)

        sd.update value: 10
        expect(company.reload.soft_delete_discard_values_sum).to eq(10)
      end
    end
  end

  it "fix_counts excludes discarded parents in multi-level counter cache" do
    skip "Discard not loaded" unless defined?(Discard::Model) && Subcateg.include?(Discard::Model)

    categ = Categ.create!
    subcateg = Subcateg.create!
    subcateg.update(fk_cat_id: categ.cat_id)
    Post.create!(subcateg: subcateg)

    expect(categ.reload.posts_count).to eq(1)

    subcateg.discard
    expect(subcateg).to be_discarded

    categ.update_column(:posts_count, 999)
    Post.counter_culture_fix_counts(only: [[:subcateg, :categ]])
    expect(categ.reload.posts_count).to eq(0)
  end

  describe "with include_soft_deleted option" do
    it "does not decrement on discard" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.discard
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end

    it "does not increment on undiscard" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      sd.discard
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.undiscard
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)
    end

    it "decrements on hard-destroy of discarded record" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      sd.discard
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(0)
    end

    it "decrements on hard-destroy of undiscarded record" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(0)
    end

    it "fix_counts includes discarded records" do
      company = Company.create!
      SoftDeleteDiscard.create!(company_id: company.id)
      sd2 = SoftDeleteDiscard.create!(company_id: company.id)
      sd2.discard

      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(2)

      company.update_column(:soft_delete_discard_include_soft_deleted_count, 0)
      SoftDeleteDiscard.counter_culture_fix_counts
      expect(company.reload.soft_delete_discard_include_soft_deleted_count).to eq(2)
      expect(company.reload.soft_delete_discards_count).to eq(1)
    end

    it "updates counter when discarded record changes association" do
      company_a = Company.create!
      company_b = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company_a.id)
      expect(company_a.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.discard
      expect(company_a.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.update!(company_id: company_b.id)
      expect(company_a.reload.soft_delete_discard_include_soft_deleted_count).to eq(0)
      expect(company_b.reload.soft_delete_discard_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company_b.reload.soft_delete_discard_include_soft_deleted_count).to eq(0)
    end

    it "fix_counts includes records with discarded parents in multi-level counter cache" do
      skip "Discard not loaded" unless defined?(Discard::Model) && Subcateg.include?(Discard::Model)

      categ = Categ.create!
      subcateg = Subcateg.create!
      subcateg.update(fk_cat_id: categ.cat_id)
      Post.create!(subcateg: subcateg)

      expect(categ.reload.posts_include_soft_deleted_count).to eq(1)

      subcateg.discard
      expect(subcateg).to be_discarded

      categ.update_column(:posts_include_soft_deleted_count, 0)
      Post.counter_culture_fix_counts(only: [[:subcateg, :categ]])
      # Regular counter excludes posts under discarded parents
      expect(categ.reload.posts_count).to eq(0)
      # include_soft_deleted counter still counts them
      expect(categ.reload.posts_include_soft_deleted_count).to eq(1)
    end

    describe "with dynamic column_name depending on soft-delete state" do
      it "increments deleted counter on discard" do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id)
        expect(company.reload.soft_delete_discard_deleted_count).to eq(0)

        sd.discard
        expect(company.reload.soft_delete_discard_deleted_count).to eq(1)
      end

      it "decrements deleted counter on undiscard" do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id)
        sd.discard
        expect(company.reload.soft_delete_discard_deleted_count).to eq(1)

        sd.undiscard
        expect(company.reload.soft_delete_discard_deleted_count).to eq(0)
      end

      it "decrements deleted counter on hard-destroy of discarded record" do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id)
        sd.discard
        expect(company.reload.soft_delete_discard_deleted_count).to eq(1)

        sd.destroy
        expect(company.reload.soft_delete_discard_deleted_count).to eq(0)
      end

      it "fix_counts correctly reconciles deleted counter" do
        company = Company.create!
        SoftDeleteDiscard.create!(company_id: company.id)
        sd2 = SoftDeleteDiscard.create!(company_id: company.id)
        sd2.discard

        expect(company.reload.soft_delete_discard_deleted_count).to eq(1)

        company.update_column(:soft_delete_discard_deleted_count, 0)
        SoftDeleteDiscard.counter_culture_fix_counts
        expect(company.reload.soft_delete_discard_deleted_count).to eq(1)
      end
    end
  end
end
