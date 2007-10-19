ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "domain"
  map.connect 'dnsmanager/zone', :controller => 'domain', :action => 'index'
  map.domain ':domain', :controller => "domain"
  map.rr ':domain/:action/:id', :controller => 'dnsmanager'
end
