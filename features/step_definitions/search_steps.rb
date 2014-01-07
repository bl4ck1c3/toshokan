Given /^I am on the front page$/ do
  visit(root_path)
end

Given /^I(?:'m| am) on the search page/ do
  visit catalog_index_path
end

Given /^I(?:'ve| have) searched for "(.*?)"$/ do |q|
  step %{I'm on the search page}
  step %{I search for "#{q}"}
end

When /^I search for "(.*?)"$/ do |query|
  fill_in('q', :with => query) 
  click_button('Find it')
end

Given /^I search for "(.*?)" in the title$/ do |query|
  step "I search for \"#{query}\" in the \"Title\" field"
end

Given /^I search for "(.*?)" in the "(.*?)" field$/ do |query, field|
  visit(catalog_index_path)
  select field, :from => 'in'
  fill_in('q', :with => query) 
  click_button('Find it')
end

Given /^I(?:'ve| have) limited the "(.*?)" facet to "(.*?)"$/ do |facet_name, facet_value|
  click_link(facet_value)
end

Then /^I should see the result page$/ do
  current_path.should match(/^\/(en|da)\/catalog$/)  
end

Then /^I should see (\d+) documents?$/ do |results|
  page.all("#documents .document").length.should == results.to_i
end

Then /^I should see a document with title "(.*?)"$/ do |title|
  page.should have_selector('.document .index_title a', text: title) 
end

Then /^I should see the search form filled with "(.*?)"$/ do |q|
  find_field('q').value.should == q
end

Then /^I should see the no hits page$/ do
  step %{I should see "No results in DTU Findit"}
  step %{I should see "Search tips"}
  step %{I should see "Need help from a DTU librarian?"}
end

Then /^I should(n't| not)? see the "can't find it\?" links$/ do |negate|
  page.send(negate ? :should_not : :should, have_selector('.cant-find-links')) 
end
