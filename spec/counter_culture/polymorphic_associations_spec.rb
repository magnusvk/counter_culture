require 'spec_helper'

RSpec.describe "CounterCulture with polymorphic_associations" do
  before(:all) do
    require 'models/poly_image'
    require 'models/poly_employee'
    require 'models/poly_product'
  end
  let(:employee) { PolyEmployee.create(id: 3000) }
  let(:product1) { PolyProduct.create() }
  let(:product2) { PolyProduct.create() }
  let(:special_url) { "http://images.example.com/special.png" }

  def mess_up_counts
    PolyEmployee.update_all(poly_images_count: 100, poly_images_count_dup: 100, special_poly_images_count: 100)
    PolyProduct.update_all(poly_images_count: 100, poly_images_count_dup: 100, special_poly_images_count: 100)
  end

  describe "default" do
    it "increments / decrements counter caches correctly" do
      expect(employee.poly_images_count).to eq(0)
      expect(product1.poly_images_count).to eq(0)
      img1 = PolyImage.create(imageable: employee)
      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(0)
      img2 = PolyImage.create(imageable: product1)
      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(1)
      img3 = PolyImage.create(imageable: product1)
      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(2)
      img3.destroy
      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(1)
      img2.imageable = employee
      img2.save!
      expect(employee.reload.poly_images_count).to eq(2)
      expect(product1.reload.poly_images_count).to eq(0)
    end

    it "decrements counter caches on update correctly" do
      img = PolyImage.create(imageable: product1)
      img.imageable = employee
      img.save!
      expect(product1.reload.poly_images_count).to eq(0)
      expect(employee.reload.poly_images_count).to eq(1)
    end

    it "can fix counts for polymorphic correctly" do
      2.times { PolyImage.create(imageable: employee) }
      1.times { PolyImage.create(imageable: product1) }
      mess_up_counts

      PolyImage.counter_culture_fix_counts

      expect(product2.reload.poly_images_count).to eq(0)
      expect(product1.reload.poly_images_count).to eq(1)
      expect(employee.reload.poly_images_count).to eq(2)
    end

    it "can fix counts for a specified polymorphic correctly" do
      2.times { PolyImage.create(imageable: employee) }
      1.times { PolyImage.create(imageable: product1) }
      mess_up_counts

      PolyImage.counter_culture_fix_counts(polymorphic_classes: PolyEmployee)

      expect(product1.reload.poly_images_count_dup).to eq(100) # unchanged
      expect(employee.reload.poly_images_count_dup).to eq(2)
    end

    it "can fix counts for multiple specified polymorphics correctly" do
      2.times { PolyImage.create(imageable: employee) }
      1.times { PolyImage.create(imageable: product1) }
      mess_up_counts

      PolyImage.counter_culture_fix_counts(
        polymorphic_classes: [PolyEmployee, PolyProduct]
      )

      expect(product1.reload.poly_images_count_dup).to eq(1)
      expect(employee.reload.poly_images_count_dup).to eq(2)
    end

    it "can handle nil values" do
      img = PolyImage.create(imageable: employee)
      PolyImage.create(imageable: nil)
      mess_up_counts

      PolyImage.counter_culture_fix_counts

      expect(employee.reload.poly_images_count).to eq(1)

      img.imageable = nil
      img.save!

      expect(employee.reload.poly_images_count).to eq(0)

      img.imageable = employee
      img.save!

      expect(employee.reload.poly_images_count).to eq(1)
    end
  end

  describe 'using custom indexes as primary keys' do
    it "increments / decrements counter caches correctly" do
      expect(employee.poly_images_from_uids_count).to eq(0)
      expect(product1.poly_images_from_uids_count).to eq(0)
      img1 = PolyImage.create(imageable_from_uid: employee)
      expect(employee.reload.poly_images_from_uids_count).to eq(1)
      expect(product1.reload.poly_images_from_uids_count).to eq(0)
      img2 = PolyImage.create(imageable_from_uid: product1)
      expect(employee.reload.poly_images_from_uids_count).to eq(1)
      expect(product1.reload.poly_images_from_uids_count).to eq(1)
      img3 = PolyImage.create(imageable_from_uid: product1)
      expect(employee.reload.poly_images_from_uids_count).to eq(1)
      expect(product1.reload.poly_images_from_uids_count).to eq(2)
      img3.destroy
      expect(employee.reload.poly_images_from_uids_count).to eq(1)
      expect(product1.reload.poly_images_from_uids_count).to eq(1)
      img2.imageable_from_uid = employee
      img2.save!
      expect(employee.reload.poly_images_from_uids_count).to eq(2)
      expect(product1.reload.poly_images_from_uids_count).to eq(0)
    end
  end

  describe "custom column name" do
    it "increments counter cache on create" do
      expect(employee.poly_images_count_dup).to eq(0)
      expect(product1.poly_images_count_dup).to eq(0)
      img1 = PolyImage.create(imageable: employee)
      expect(employee.reload.poly_images_count_dup).to eq(1)
      expect(product1.reload.poly_images_count_dup).to eq(0)
      img2 = PolyImage.create(imageable: product1)
      expect(employee.reload.poly_images_count_dup).to eq(1)
      expect(product1.reload.poly_images_count_dup).to eq(1)
      img3 = PolyImage.create(imageable: product1)
      expect(employee.reload.poly_images_count_dup).to eq(1)
      expect(product1.reload.poly_images_count_dup).to eq(2)
      img3.destroy
      expect(employee.reload.poly_images_count_dup).to eq(1)
      expect(product1.reload.poly_images_count_dup).to eq(1)
      img2.imageable = employee
      img2.save!
      expect(employee.reload.poly_images_count_dup).to eq(2)
      expect(product1.reload.poly_images_count_dup).to eq(0)
    end

    it "decrements counter caches on update correctly" do
      img = PolyImage.create(imageable: product1)
      img.imageable = employee
      img.save!
      expect(employee.reload.poly_images_count_dup).to eq(1)
      expect(product1.reload.poly_images_count_dup).to eq(0)
    end

    it "can fix counts for polymorphic correctly" do
      2.times { PolyImage.create(imageable: employee) }
      1.times { PolyImage.create(imageable: product1) }
      mess_up_counts

      PolyImage.counter_culture_fix_counts

      expect(product2.reload.poly_images_count_dup).to eq(0)
      expect(product1.reload.poly_images_count_dup).to eq(1)
      expect(employee.reload.poly_images_count_dup).to eq(2)
    end
  end
  describe "conditional counts" do
    it "increments counter cache on create" do
      expect(employee.special_poly_images_count).to eq(0)
      expect(product1.special_poly_images_count).to eq(0)
      PolyImage.create(imageable: employee)
      expect(employee.reload.special_poly_images_count).to eq(0)
      expect(product1.special_poly_images_count).to eq(0)
      PolyImage.create(imageable: product1)
      expect(employee.reload.special_poly_images_count).to eq(0)
      expect(product1.reload.special_poly_images_count).to eq(0)
      img1 = PolyImage.create(imageable: employee, url: special_url)
      expect(employee.reload.special_poly_images_count).to eq(1)
      expect(product1.special_poly_images_count).to eq(0)
      img2 = PolyImage.create(imageable: product1, url: special_url)
      expect(employee.reload.special_poly_images_count).to eq(1)
      expect(product1.reload.special_poly_images_count).to eq(1)
      img2.destroy
      expect(employee.reload.special_poly_images_count).to eq(1)
      expect(product1.reload.special_poly_images_count).to eq(0)
      img1.imageable = product1
      img1.save!
      expect(employee.reload.special_poly_images_count).to eq(0)
      expect(product1.reload.special_poly_images_count).to eq(1)
    end

    it "can fix counts for polymorphic correctly" do
      4.times { PolyImage.create(imageable: employee) }
      2.times { PolyImage.create(imageable: employee, url: special_url) }
      1.times { PolyImage.create(imageable: product1) }
      1.times { PolyImage.create(imageable: product1, url: special_url) }
      mess_up_counts

      PolyImage.counter_culture_fix_counts

      expect(product2.reload.special_poly_images_count).to eq(0)
      expect(employee.reload.special_poly_images_count).to eq(2)
      expect(product1.reload.special_poly_images_count).to eq(1)
    end

    it "can deal with changes to condition" do
      img1 = PolyImage.create(imageable: employee)
      expect {img1.update!(url: special_url)}
        .to change { employee.reload.special_poly_images_count }.from(0).to(1)
    end

    it "can deal with changes to condition" do
      img1 = PolyImage.create(imageable: employee, url: special_url)
      expect {img1.update!(url: "normal url")}
        .to change { employee.reload.special_poly_images_count }.from(1).to(0)
    end
  end
end
