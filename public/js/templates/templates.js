(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['search-results'] = template({"1":function(container,depth0,helpers,partials,data) {
    return "            <th>"
    + container.escapeExpression(container.lambda(depth0, depth0))
    + "</th>\n";
},"3":function(container,depth0,helpers,partials,data) {
    var stack1, alias1=container.lambda, alias2=container.escapeExpression;

  return "          <tr>\n            <td><input name=\"sample_id[]\" type=\"checkbox\" value=\""
    + alias2(alias1((depth0 != null ? depth0.specimen__sample_id : depth0), depth0))
    + "\"></td>\n            <td><a target=\"_blank\" href=\"/sample/view/"
    + alias2(alias1((depth0 != null ? depth0.specimen__sample_id : depth0), depth0))
    + "\">"
    + alias2(alias1((depth0 != null ? depth0.specimen__sample_name : depth0), depth0))
    + "</a></td>\n            <td><a target=\"_blank\" href=\"/project/view/"
    + alias2(alias1((depth0 != null ? depth0.specimen__project_id : depth0), depth0))
    + "\">"
    + alias2(alias1((depth0 != null ? depth0.specimen__project_name : depth0), depth0))
    + "</a></td>\n"
    + ((stack1 = helpers.each.call(depth0 != null ? depth0 : (container.nullContext || {}),(depth0 != null ? depth0.search_values : depth0),{"name":"each","hash":{},"fn":container.program(4, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "");
},"4":function(container,depth0,helpers,partials,data) {
    return "              <td>"
    + container.escapeExpression(container.lambda(depth0, depth0))
    + "</td>\n";
},"compiler":[7,">= 4.0.0"],"main":function(container,depth0,helpers,partials,data) {
    var stack1, helper, alias1=depth0 != null ? depth0 : (container.nullContext || {}), alias2=helpers.helperMissing, alias3="function", alias4=container.escapeExpression;

  return "  <div class=\"row\">\n    <h2 id=\"nav-tabs\">Results: "
    + alias4(((helper = (helper = helpers.count || (depth0 != null ? depth0.count : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"count","hash":{},"data":data}) : helper)))
    + "</h2>\n    <div class=\"pull-right\">\n      <a class=\"btn btn-default\" href=\"/sample/search_results_map?"
    + alias4(((helper = (helper = helpers.formData || (depth0 != null ? depth0.formData : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"formData","hash":{},"data":data}) : helper)))
    + "\" target=\"_blank\">View On Map</a>\n      <a class=\"btn btn-default\" data-toggle=\"collapse\" href=\"#permalink\" aria-expanded=\"false\" aria-controls=\"permalink\">Permalink</a>\n      <a class=\"btn btn-default\" onclick=\"addToCart()\">Add To Cart</a>\n      <a class=\"btn btn-default\" href=\"/sample/search_results.tab?"
    + alias4(((helper = (helper = helpers.formData || (depth0 != null ? depth0.formData : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"formData","hash":{},"data":data}) : helper)))
    + "&download=1\" target=\"_blank\">Download</a>\n      <div class=\"collapse\" id=\"permalink\">\n        <div class=\"well\">\n          <a href=\"/sample/search?"
    + alias4(((helper = (helper = helpers.formData || (depth0 != null ? depth0.formData : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"formData","hash":{},"data":data}) : helper)))
    + "\">/sample/search_results_map?"
    + alias4(((helper = (helper = helpers.formData || (depth0 != null ? depth0.formData : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"formData","hash":{},"data":data}) : helper)))
    + "</a>\n        </div>\n      </div>\n    </div>\n    <table id=\"samples-tbl\" class=\"table\" cellspacing=\"0\" width=\"100%\">\n      <thead>\n        <tr>\n          <th><input id=\"toggler\" type=\"checkbox\" onclick=\"toggleAll()\"></th>\n          <th>Sample</th>\n          <th>Project</th>\n"
    + ((stack1 = helpers.each.call(alias1,(depth0 != null ? depth0.search_fields_pretty : depth0),{"name":"each","hash":{},"fn":container.program(1, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "        </tr>\n      </thead>\n      <tbody>\n"
    + ((stack1 = helpers.each.call(alias1,(depth0 != null ? depth0.samples : depth0),{"name":"each","hash":{},"fn":container.program(3, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "      </tbody>\n    </table>\n  </div>\n";
},"useData":true});
})();