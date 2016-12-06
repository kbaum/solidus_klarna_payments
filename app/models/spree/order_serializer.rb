module Spree
  class OrderSerializer
    attr_reader :order, :region
    attr_accessor :options, :design, :skip_personal_data
    attr_writer :store

    def initialize(order, region = :us)
      @order = order
      @region = region.downcase.to_sym
      @options = {}
    end

    def to_hash
      strategy.adjust_with(order) do
        config
      end
    end

    def addresses
      {
        billing_address: billing_address,
        shipping_address: shipping_address
      }
    end

    private

    def config
      {
        purchase_country: order.billing_address.country.iso,
        purchase_currency: order.currency,
        locale: strategy.locale(region),
        # amount with taxes and adjustments
        order_amount: order.display_total.cents,
        billing_address: billing_address,
        shipping_address: shipping_address,
        order_lines: order_lines,
        merchant_reference1: order.number,
        options: options,
        design: design,
        merchant_urls: merchant_urls
      }.delete_if { |k, v| v.nil? }
    end

    def order_lines
      line_items + shipments
    end

    def line_items
      order.line_items.map do |line_item|
        LineItemSerializer.new(line_item, strategy.line_item_strategy).to_hash
      end
    end

    def shipments
      order.shipments.map do |shipment|
        ShipmentSerializer.new(shipment, strategy.shipment_strategy).to_hash
      end
    end

    def billing_address
      {
        email: @order.email
      }.merge(
        AddressSerializer.new(order.billing_address).to_hash
      )
    end

    def shipping_address
      {
        email: @order.email
      }.merge(
        AddressSerializer.new(order.shipping_address).to_hash
      )
    end

    def strategy
      @strategy ||= case region
        when :us then Spree::AmountCalculators::US::OrderCalculator.new
        else Spree::AmountCalculators::UK::OrderCalculator.new(skip_personal_data)
        end
    end

    def merchant_urls
      {
        # TODO: use the current store url
        # terms: "http://#{Spree::Store.first.url}/terms",
        # checkout: "http://#{Spree::Store.first.url}/orders/#{@order.number}",
        # push: "http://#{Spree::Store.first.url}/klarna/push",
        # validation: "string",
        # shipping_option_update: "string",
        # address_update: "string",
        # country_change: "string",
        confirmation: url_helpers.order_url(@order.number, host: store.url),
        notification: url_helpers.klarna_notification_url(host: store.url)
      }
    end

    def store
      @store || Spree::Store.first
    end

    def url_helpers
      Spree::Core::Engine.routes.url_helpers
    end
  end
end