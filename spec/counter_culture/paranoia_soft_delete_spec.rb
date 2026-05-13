require 'spec_helper'

RSpec.describe "CounterCulture when using paranoia for soft deletes" do
  it "works" do
    company = Company.create!
    expect(company.soft_delete_paranoia_count).to eq(0)
    sd = SoftDeleteParanoia.create!(company_id: company.id)
    expect(company.reload.soft_delete_paranoia_count).to eq(1)

    sd.destroy
    sd.reload
    expect(sd.deleted_at).to be_truthy
    expect(company.reload.soft_delete_paranoia_count).to eq(0)

    company.update(soft_delete_paranoia_count: 100)
    expect(company.reload.soft_delete_paranoia_count).to eq(100)
    SoftDeleteParanoia.counter_culture_fix_counts
    expect(company.reload.soft_delete_paranoia_count).to eq(0)

    sd.restore
    expect(company.reload.soft_delete_paranoia_count).to eq(1)
  end

  it "runs destroy callback only once" do
    company = Company.create!
    sd = SoftDeleteParanoia.create!(company_id: company.id)

    expect(company.reload.soft_delete_paranoia_count).to eq(1)

    sd.destroy
    expect(company.reload.soft_delete_paranoia_count).to eq(0)

    sd.destroy
    expect(company.reload.soft_delete_paranoia_count).to eq(0)
  end

  it "runs restore callback only once" do
    company = Company.create!
    sd = SoftDeleteParanoia.create!(company_id: company.id)

    expect(company.reload.soft_delete_paranoia_count).to eq(1)

    sd.destroy
    expect(company.reload.soft_delete_paranoia_count).to eq(0)

    sd.restore
    expect(company.reload.soft_delete_paranoia_count).to eq(1)

    sd.restore
    expect(company.reload.soft_delete_paranoia_count).to eq(1)
  end

  describe "when calling paranoia really destroy" do
    it "does not run destroy callback for paranoia destroyed records" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)

      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.really_destroy!
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end

    it "runs really destroy callback for paranoia undestroyed records" do
      company = Company.create!
      expect(company.soft_delete_paranoia_count).to eq(0)
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.really_destroy!
      expect{ sd.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end
  end

  describe "dynamic column names with totaling instead of counting" do
    describe 'when updating soft deleted records' do
      it 'does not update sum' do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id, value: 5)

        expect(company.reload.soft_delete_paranoia_values_sum).to eq(5)

        sd.destroy
        expect(company.reload.soft_delete_paranoia_values_sum).to eq(0)

        sd.update value: 10
        expect(company.reload.soft_delete_paranoia_values_sum).to eq(0)
      end
    end

    describe 'when updating undestroyed records' do
      it 'updates sum' do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id, value: 5)

        expect(company.reload.soft_delete_paranoia_values_sum).to eq(5)

        sd.update value: 10
        expect(company.reload.soft_delete_paranoia_values_sum).to eq(10)
      end
    end
  end

  it "fix_counts excludes soft-deleted parents in multi-level counter cache" do
    skip "Paranoia not loaded" unless Subcateg.respond_to?(:acts_as_paranoid)

    categ = Categ.create!
    subcateg = Subcateg.create!
    subcateg.update(fk_cat_id: categ.cat_id)
    Post.create!(subcateg: subcateg)

    expect(categ.reload.posts_count).to eq(1)

    subcateg.destroy
    expect(subcateg.deleted_at).to be_present

    categ.update_column(:posts_count, 999)
    Post.counter_culture_fix_counts(only: [[:subcateg, :categ]])
    expect(categ.reload.posts_count).to eq(0)
  end

  describe "with include_soft_deleted option" do
    it "does not decrement on soft delete" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end

    it "does not increment on restore" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.restore
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)
    end

    it "decrements on really_destroy! of soft-deleted record" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.really_destroy!
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(0)
    end

    it "decrements on really_destroy! of non-soft-deleted record" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.really_destroy!
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(0)
    end

    it "fix_counts includes soft-deleted records" do
      company = Company.create!
      SoftDeleteParanoia.create!(company_id: company.id)
      sd2 = SoftDeleteParanoia.create!(company_id: company.id)
      sd2.destroy

      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(2)

      company.update_column(:soft_delete_paranoia_include_soft_deleted_count, 0)
      SoftDeleteParanoia.counter_culture_fix_counts
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(2)
      expect(company.reload.soft_delete_paranoia_count).to eq(1)
    end

    it "handles repeated soft-delete without issues" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)
    end

    it "updates counter when soft-deleted record changes association" do
      company_a = Company.create!
      company_b = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company_a.id)
      expect(company_a.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company_a.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.update!(company_id: company_b.id)
      expect(company_a.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(0)
      expect(company_b.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.really_destroy!
      expect(company_b.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(0)
    end

    it "fix_counts includes records with soft-deleted parents in multi-level counter cache" do
      skip "Paranoia not loaded" unless Subcateg.respond_to?(:acts_as_paranoid)

      categ = Categ.create!
      subcateg = Subcateg.create!
      subcateg.update(fk_cat_id: categ.cat_id)
      Post.create!(subcateg: subcateg)

      expect(categ.reload.posts_include_soft_deleted_count).to eq(1)

      subcateg.destroy
      expect(subcateg.deleted_at).to be_present

      categ.update_column(:posts_include_soft_deleted_count, 0)
      Post.counter_culture_fix_counts(only: [[:subcateg, :categ]])
      # Regular counter excludes posts under soft-deleted parents
      expect(categ.reload.posts_count).to eq(0)
      # include_soft_deleted counter still counts them
      expect(categ.reload.posts_include_soft_deleted_count).to eq(1)
    end

    describe "with dynamic column_name depending on soft-delete state" do
      it "increments deleted counter on soft-delete" do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id)
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(0)

        sd.destroy
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(1)
      end

      it "decrements deleted counter on restore" do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id)
        sd.destroy
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(1)

        sd.restore
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(0)
      end

      it "decrements deleted counter on really_destroy! of soft-deleted record" do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id)
        sd.destroy
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(1)

        sd.really_destroy!
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(0)
      end

      it "fix_counts correctly reconciles deleted counter" do
        company = Company.create!
        SoftDeleteParanoia.create!(company_id: company.id)
        sd2 = SoftDeleteParanoia.create!(company_id: company.id)
        sd2.destroy

        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(1)

        company.update_column(:soft_delete_paranoia_deleted_count, 0)
        SoftDeleteParanoia.counter_culture_fix_counts
        expect(company.reload.soft_delete_paranoia_deleted_count).to eq(1)
      end
    end
  end
end
