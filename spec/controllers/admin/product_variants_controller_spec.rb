#encoding: utf-8
require 'spec_helper'

describe Admin::ProductVariantsController do
  include Devise::TestHelpers

  let(:user) { Factory(:user_admin) }

  let(:shop) { user.shop }

  let(:iphone4) {Factory(:iphone4, shop: shop)}

  before :each do
    request.host = "#{shop.primary_domain.host}"
    sign_in(user)
  end

  context '#create' do

    it "should set default price and weight" do # issue#205
      iphone4
      expect do
        post :create, product_id: iphone4.id, product_variant: {option1: '16G', price: nil, weight: nil}
        response.should be_success
      end.should change(ProductVariant, :count).by(1)
    end

    it "should cant create new variant when sku is limited" ,focus: true do # issue#284
      iphone4
      shop.plan_type.stub!(:skus).and_return(1)
      expect do
        post :create, product_id: iphone4.id, product_variant: {option1: '16G', price: nil, weight: nil}
        response.should be_success
      end.should change(ProductVariant, :count).by(0)
    end
  end

  context '#create' do
    it "should update variant " ,focus: true do # issue#284
      iphone4
      variant = iphone4.variants.first
      expect do
        put :update, product_id: iphone4.id, product_variant: {compare_at_price: "", id: variant.id,  price: "111", product_id: iphone4.id, shop_id: shop.id},  id: variant.id
        response.should be_success
        variant.reload
      end.should change(variant, :price).from(3000).to(111)
    end

    it "should cant update  variant when sku is limited" ,focus: true do # issue#284
      iphone4
      variant = iphone4.variants.first
      shop.plan_type.stub!(:skus).and_return(1)
      expect do
        put :update, product_id: iphone4.id, product_variant: {compare_at_price: "", id: iphone4.variants.first.id,  price: "111", product_id: iphone4.id, shop_id: shop.id},  id: iphone4.variants.first.id
        response.should be_success
        variant.reload
      end.should_not change(variant, :price).from(3000).to(111)
    end

  end

end
