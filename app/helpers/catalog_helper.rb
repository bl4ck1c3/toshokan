# encoding: utf-8
module CatalogHelper
  include Blacklight::CatalogHelperBehavior

  # Should we display the pagination controls?
  #
  # @param [Blacklight::SolrResponse]
  # @return [Boolean]
  def show_pagination? response = nil
    response ||= @response
    response.limit_value > 0 && response.total_pages > 1
  end

  def extra_body_classes
    controller_name = controller.controller_name
    controller_action = controller.action_name
    unless params[:resolve].blank?
      controller_name = CatalogController.controller_name
      controller_action = "show"
    end
    ['blacklight-' + controller_name, 'blacklight-' + [controller_name, controller_action].join('-')]
  end

end
