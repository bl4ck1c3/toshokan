module OrdersHelper
  def render_scan_price_tag user, supplier, currency = :DKK
    html = "<div class=\"price\">#{t 'toshokan.orders.price'}: #{format_price PayIt::Prices.price_with_vat(user, supplier, currency), currency}"
    discount_type = PayIt::Prices.discount_type user
    if discount_type
      html += "<div class=\"discount\">(#{t "toshokan.orders.discount_types.#{discount_type}"} applied)</div>"
    end
    html.html_safe
  end

  def render_order_steps order_flow
    step = 0
    steps = order_flow.steps.collect do |v|
      step += 1
      "#{step}. #{I18n.t 'toshokan.orders.steps.' + v.to_s}"
    end
    steps[order_flow.current_step_idx] = "<b>#{steps[order_flow.current_step_idx]}</b>"
    "<div class=\"steps\">#{steps.join(' &rarr; ')}</div>".html_safe
  end

  def format_price price, currency = :DKK
    number_to_currency price.to_f/100, :unit => currency.to_s, :format => '%u %n'
  end
end
