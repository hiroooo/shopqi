#encoding: utf-8
require 'spec_helper'

describe Order do

  let(:shop) { Factory(:user).shop }

  let(:iphone4) { Factory :iphone4, shop: shop }

  let(:variant) { iphone4.variants.first }

  let(:payment) { Factory :payment, shop: shop }

  let(:order) do
    o = Factory.build(:order, shop: shop, email: 'admin@shopqi.com', shipping_rate: '普通快递-10.0', payment_id: payment.id)
    o.line_items.build product_variant: variant, price: 10, quantity: 2
    o.save
    o
  end

  let(:line_item) { order.line_items.first }

  describe Customer do

    it 'should be add' do
      shop
      expect do
        expect do
          order
        end.should change(Customer, :count).by(1)
      end.should change(CustomerAddress, :count).by(1)
      order.customer.should_not be_nil
    end

  end

  describe OrderTransaction do

    let(:transaction) { order.transactions.create kind: :capture }

    it 'should be add' do
      expect do
        transaction
      end.should change(OrderTransaction, :count).by(1)
    end

    it 'should save history' do
      order
      expect do
        transaction
      end.should change(OrderHistory, :count).by(1)
    end

    context 'enough amount' do # 完整支付

      it 'should change order financial_status to paid' do
        transaction
        order.reload.financial_status_paid?.should be_true
      end

    end

    context 'no enough amount' do # 部分支付

      let(:transaction) { order.transactions.create kind: :capture, amount: 1 }

      it 'should not change order financial_status' do
        transaction
        order.reload.financial_status_paid?.should_not be_true
      end

    end

  end

  describe OrderLineItem do

    it 'should set variant attributes' do
      line_item.title.should eql iphone4.title
      line_item.variant_title.should be_nil
      line_item.name.should eql variant.name
      line_item.vendor.should eql iphone4.vendor
      line_item.requires_shipping.should eql variant.requires_shipping
      line_item.grams.should eql (variant.weight * 1000).to_i
      line_item.sku.should eql variant.sku
    end

  end

  describe OrderFulfillment do

    let(:fulfillment) do
      record = order.fulfillments.build notify_customer: 'true'
      record.line_items << line_item
      record.save
      record
    end

    it 'should be add' do
      expect do
        fulfillment
      end.should change(OrderFulfillment, :count).by(1)
      line_item.reload.fulfilled.should be_true
      order.reload.fulfillment_status.should eql 'fulfilled'
    end

    it 'should save history' do
      order
      expect do
        fulfillment
        order.histories.first.url.should_not be_blank
      end.should change(OrderHistory, :count).by(1)
    end

    describe 'email' do

      before { ActionMailer::Base.deliveries.clear }

      context '#create' do

        it 'should send email to customer' do # 给顾客发送发货通知邮件
          with_resque do
            ActionMailer::Base.deliveries.empty?.should be_true
            fulfillment
            ActionMailer::Base.deliveries.empty?.should be_false
            email = ActionMailer::Base.deliveries.last
            email.subject.should eql "订单 #1001 发货提醒\n"
          end
        end

      end

      context '#update' do

        it 'should send email to customer' do # 给顾客发送发货更新邮件
          with_resque do
            fulfillment
            fulfillment.update_attributes! tracking_number: 'abcd1234' # 更新属性并保存，此时发邮件
            fulfillment.save # 未做任何修改时保存，不要发邮件
            ActionMailer::Base.deliveries.size.should eql 4 # 下单成功、下单通知、发货通知、发货修改
            email = ActionMailer::Base.deliveries.last
            email.subject.should eql "订单 #1001 运送方式更改提醒\n"
          end
        end

      end

    end

    describe 'alipay' do # 集成支付宝担保交易发货接口

      let(:fulfillment) do
        record = order.fulfillments.build notify_customer: 'true', tracking_number: 'abcd1234', tracking_company: '申通E物流'
        record.line_items << line_item
        record.save
        record
      end

      let(:trade_no) { '2012041441700373' } # 支付宝交易号

      let(:payment) { Factory :payment_alipay_escrow, shop: shop } # 支付方式:支付宝

      before do
        order.trade_no = trade_no
        order.save
      end

      it 'should receive send goods' do # 接受到发货信息
        options = { 'logistics_name' => '申通E物流', 'invoice_no' => 'abcd1234', 'trade_no' => trade_no }
        Gateway::Alipay.should_receive(:send_goods).with(options, payment.account, payment.key, payment.email)
        with_resque do
          fulfillment
        end
      end

    end

  end

  describe 'validate' do # 校验

    let(:order) do
      o = shop.orders.build
      o.line_items.build product_variant: variant, price: 10, quantity: 2
      o
    end

    it 'should be perform' do
      order.valid?.should be_false
      order.errors[:email].should_not be_empty
      order.errors[:shipping_rate].should_not be_empty
      order.errors[:payment_id].should_not be_empty
    end

    it 'should validate shipping_address' do
      order.update_attributes email: 'mahb45@gmail.com', shipping_address_attributes: { name: '' }
      order.errors['shipping_address.name'].should_not be_empty
    end

    context 'free order' do # 免费订单

      let(:free_shipping_rate){ shop.shippings.first.weight_based_shipping_rates.create name: '免费快递', price: 0 } # 全国免运费

      before { free_shipping_rate }

      context 'without discount' do # 没有优惠码

        let(:free_order) do
          o = Factory.build(:order, shop: shop, email: 'admin@shopqi.com', shipping_rate: '免费快递-0.0')
          o.line_items.build product_variant: variant, price: 0, quantity: 1
          o.save
          o
        end

        it 'should not validate payment' do # 不需要支付
          free_order.total_price.should be_zero
          free_order.errors.should be_empty
          free_order.financial_status_paid?.should be_true
        end

      end

      context 'discount' do # 使用了优惠码

        let(:discount) { shop.discounts.create code: 'coupon123', value: 20 }

        let(:order) do
          o = Factory.build(:order, shop: shop, email: 'admin@shopqi.com', shipping_rate: '免费快递-0.0', discount_code: discount.code)
          o.line_items.build product_variant: variant, price: 10, quantity: 1
          o.save
          o
        end

        it 'should not validate payment' do # 不需要支付
          order.total_price.should be_zero
          order.errors.should be_empty
          order.financial_status_paid?.should be_true
        end

      end

    end

    #it 'should validate shipping_rate' do # 商店要支持的配送方式
    #  order.update_attributes email: 'mahb45@gmail.com', shipping_rate: "顺丰快递-0"
    #  order.errors['shipping_rate'].should_not be_empty
    #end

  end

  describe 'create' do

    it 'should save total_price' do
      order.subtotal_price.should eql 20.0
      order.total_price.should eql 30.0
    end

    it 'should save address' do
      expect do
        expect do
          order
        end.should change(Order, :count).by(1)
      end.should change(OrderShippingAddress, :count).by(1)
    end

    it 'should save name' do
      order.number.should eql 1
      order.order_number.should eql 1001
      order.name.should eql '#1001'
    end

    it 'should save history' do
      expect do
        order
      end.should change(OrderHistory, :count).by(1)
    end

  end

  describe 'update' do

    it 'should validate gateway' do
      order.save
      order.errors[:gateway].should_not be_nil
    end

  end

end
