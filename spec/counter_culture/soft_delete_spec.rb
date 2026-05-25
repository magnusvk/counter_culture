require 'spec_helper'

RSpec.describe "CounterCulture soft delete" do
  # The discard and paranoia integrations are behaviourally identical; only the
  # model, the column names, and the soft-delete/restore/hard-destroy method
  # names differ. The shared examples below are parameterized via `let`s and
  # the helper methods defined in each context. Genuinely gem-specific tests
  # (paranoia's `really_destroy!` semantics and its repeated-soft-delete case,
  # discard's hard `destroy` of a live record) are written explicitly per
  # context so no assertion is lost to the generalization.
  shared_examples "a soft-deletable counter cache" do
    it "works" do
      company = Company.create!
      expect(company.public_send(count_column)).to eq(0)
      record = model.create!(company_id: company.id)
      expect(company.reload.public_send(count_column)).to eq(1)

      soft_delete(record)
      record.reload
      expect_soft_deleted(record)
      expect(company.reload.public_send(count_column)).to eq(0)

      company.update(count_column => 100)
      expect(company.reload.public_send(count_column)).to eq(100)
      model.counter_culture_fix_counts
      expect(company.reload.public_send(count_column)).to eq(0)

      restore(record)
      expect(company.reload.public_send(count_column)).to eq(1)
    end

    it "runs destroy callback only once" do
      company = Company.create!
      record = model.create!(company_id: company.id)

      expect(company.reload.public_send(count_column)).to eq(1)

      soft_delete(record)
      expect(company.reload.public_send(count_column)).to eq(0)

      soft_delete(record)
      expect(company.reload.public_send(count_column)).to eq(0)
    end

    it "runs restore callback only once" do
      company = Company.create!
      record = model.create!(company_id: company.id)

      expect(company.reload.public_send(count_column)).to eq(1)

      soft_delete(record)
      expect(company.reload.public_send(count_column)).to eq(0)

      restore(record)
      expect(company.reload.public_send(count_column)).to eq(1)

      restore(record)
      expect(company.reload.public_send(count_column)).to eq(1)
    end

    describe "when hard-destroying a soft-deleted record" do
      it "does not change the counter again" do
        company = Company.create!
        record = model.create!(company_id: company.id)

        expect(company.reload.public_send(count_column)).to eq(1)

        soft_delete(record)
        expect(company.reload.public_send(count_column)).to eq(0)

        hard_destroy(record)
        expect(company.reload.public_send(count_column)).to eq(0)
      end
    end

    describe "dynamic column names with totaling instead of counting" do
      describe "when updating soft-deleted records" do
        it "does not update sum" do
          company = Company.create!
          record = model.create!(company_id: company.id, value: 5)

          expect(company.reload.public_send(sum_column)).to eq(5)

          soft_delete(record)
          expect(company.reload.public_send(sum_column)).to eq(0)

          record.update(value: 10)
          expect(company.reload.public_send(sum_column)).to eq(0)
        end
      end

      describe "when updating live records" do
        it "updates sum" do
          company = Company.create!
          record = model.create!(company_id: company.id, value: 5)

          expect(company.reload.public_send(sum_column)).to eq(5)

          record.update(value: 10)
          expect(company.reload.public_send(sum_column)).to eq(10)
        end
      end
    end

    it "fix_counts excludes soft-deleted parents in multi-level counter cache" do
      skip "#{soft_delete_label} not loaded" unless parent_soft_delete_loaded?

      categ = Categ.create!
      subcateg = Subcateg.create!
      subcateg.update(fk_cat_id: categ.cat_id)
      Post.create!(subcateg: subcateg)

      expect(categ.reload.posts_count).to eq(1)

      parent_soft_delete(subcateg)
      expect_parent_soft_deleted(subcateg)

      categ.update_column(:posts_count, 999)
      Post.counter_culture_fix_counts(only: [[:subcateg, :categ]])
      expect(categ.reload.posts_count).to eq(0)
    end

    describe "with include_soft_deleted option" do
      it "does not decrement on soft-delete" do
        company = Company.create!
        record = model.create!(company_id: company.id)
        expect(company.reload.public_send(include_column)).to eq(1)

        soft_delete(record)
        expect(company.reload.public_send(include_column)).to eq(1)
        expect(company.reload.public_send(count_column)).to eq(0)
      end

      it "does not increment on restore" do
        company = Company.create!
        record = model.create!(company_id: company.id)
        soft_delete(record)
        expect(company.reload.public_send(include_column)).to eq(1)

        restore(record)
        expect(company.reload.public_send(include_column)).to eq(1)
      end

      it "decrements on hard-destroy of soft-deleted record" do
        company = Company.create!
        record = model.create!(company_id: company.id)
        soft_delete(record)
        expect(company.reload.public_send(include_column)).to eq(1)

        hard_destroy(record)
        expect(company.reload.public_send(include_column)).to eq(0)
      end

      it "decrements on hard-destroy of live record" do
        company = Company.create!
        record = model.create!(company_id: company.id)
        expect(company.reload.public_send(include_column)).to eq(1)

        hard_destroy(record)
        expect(company.reload.public_send(include_column)).to eq(0)
      end

      it "fix_counts includes soft-deleted records" do
        company = Company.create!
        model.create!(company_id: company.id)
        record2 = model.create!(company_id: company.id)
        soft_delete(record2)

        expect(company.reload.public_send(include_column)).to eq(2)

        company.update_column(include_column, 0)
        model.counter_culture_fix_counts
        expect(company.reload.public_send(include_column)).to eq(2)
        expect(company.reload.public_send(count_column)).to eq(1)
      end

      it "updates counter when soft-deleted record changes association" do
        company_a = Company.create!
        company_b = Company.create!
        record = model.create!(company_id: company_a.id)
        expect(company_a.reload.public_send(include_column)).to eq(1)

        soft_delete(record)
        expect(company_a.reload.public_send(include_column)).to eq(1)

        record.update!(company_id: company_b.id)
        expect(company_a.reload.public_send(include_column)).to eq(0)
        expect(company_b.reload.public_send(include_column)).to eq(1)

        hard_destroy(record)
        expect(company_b.reload.public_send(include_column)).to eq(0)
      end

      it "fix_counts includes records with soft-deleted parents in multi-level counter cache" do
        skip "#{soft_delete_label} not loaded" unless parent_soft_delete_loaded?

        categ = Categ.create!
        subcateg = Subcateg.create!
        subcateg.update(fk_cat_id: categ.cat_id)
        Post.create!(subcateg: subcateg)

        expect(categ.reload.posts_include_soft_deleted_count).to eq(1)

        parent_soft_delete(subcateg)
        expect_parent_soft_deleted(subcateg)

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
          record = model.create!(company_id: company.id)
          expect(company.reload.public_send(deleted_column)).to eq(0)

          soft_delete(record)
          expect(company.reload.public_send(deleted_column)).to eq(1)
        end

        it "decrements deleted counter on restore" do
          company = Company.create!
          record = model.create!(company_id: company.id)
          soft_delete(record)
          expect(company.reload.public_send(deleted_column)).to eq(1)

          restore(record)
          expect(company.reload.public_send(deleted_column)).to eq(0)
        end

        it "decrements deleted counter on hard-destroy of soft-deleted record" do
          company = Company.create!
          record = model.create!(company_id: company.id)
          soft_delete(record)
          expect(company.reload.public_send(deleted_column)).to eq(1)

          hard_destroy(record)
          expect(company.reload.public_send(deleted_column)).to eq(0)
        end

        it "fix_counts correctly reconciles deleted counter" do
          company = Company.create!
          model.create!(company_id: company.id)
          record2 = model.create!(company_id: company.id)
          soft_delete(record2)

          expect(company.reload.public_send(deleted_column)).to eq(1)

          company.update_column(deleted_column, 0)
          model.counter_culture_fix_counts
          expect(company.reload.public_send(deleted_column)).to eq(1)
        end
      end
    end
  end

  context "with discard" do
    let(:model) { SoftDeleteDiscard }
    let(:count_column) { :soft_delete_discards_count }
    let(:sum_column) { :soft_delete_discard_values_sum }
    let(:include_column) { :soft_delete_discard_include_soft_deleted_count }
    let(:deleted_column) { :soft_delete_discard_deleted_count }
    let(:soft_delete_label) { "Discard" }

    def soft_delete(record)
      record.discard
    end

    def restore(record)
      record.undiscard
    end

    def hard_destroy(record)
      record.destroy
    end

    def expect_soft_deleted(record)
      expect(record).to be_discarded
    end

    def parent_soft_delete(subcateg)
      subcateg.discard
    end

    def expect_parent_soft_deleted(subcateg)
      expect(subcateg).to be_discarded
    end

    def parent_soft_delete_loaded?
      defined?(Discard::Model) && Subcateg.include?(Discard::Model)
    end

    it_behaves_like "a soft-deletable counter cache"

    # discard's regular `destroy` is a hard destroy; paranoia's is not, so this
    # case has no shared equivalent and stays gem-specific.
    it "runs destroy callback for undiscarded records" do
      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end
  end

  context "with paranoia" do
    let(:model) { SoftDeleteParanoia }
    let(:count_column) { :soft_delete_paranoia_count }
    let(:sum_column) { :soft_delete_paranoia_values_sum }
    let(:include_column) { :soft_delete_paranoia_include_soft_deleted_count }
    let(:deleted_column) { :soft_delete_paranoia_deleted_count }
    let(:soft_delete_label) { "Paranoia" }

    def soft_delete(record)
      record.destroy
    end

    def restore(record)
      record.restore
    end

    def hard_destroy(record)
      record.really_destroy!
    end

    def expect_soft_deleted(record)
      expect(record.deleted_at).to be_truthy
    end

    def parent_soft_delete(subcateg)
      subcateg.destroy
    end

    def expect_parent_soft_deleted(subcateg)
      expect(subcateg.deleted_at).to be_present
    end

    def parent_soft_delete_loaded?
      Subcateg.respond_to?(:acts_as_paranoid)
    end

    it_behaves_like "a soft-deletable counter cache"

    # `really_destroy!` of a live record additionally hard-deletes the row;
    # this asserts the record is truly gone, which has no discard equivalent.
    it "runs really destroy callback for paranoia undestroyed records" do
      company = Company.create!
      expect(company.soft_delete_paranoia_count).to eq(0)
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.really_destroy!
      expect{ sd.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end

    it "handles repeated soft-delete without issues" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_include_soft_deleted_count).to eq(1)
    end
  end
end
