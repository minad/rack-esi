[ESI]: http://www.w3.org/TR/esi-lang
[Rack::Cache]: http://tomayko.com/src/rack-cache/

# Rack::ESI

Rack::ESI is an implementation of a small (but still very useful!) subset of [ESI][].

It allows you to _easily_ cache everything but the user-customized parts of your dynamic pages without leaving the comfortable world of Ruby when used together with [Ryan Tomayko's Rack::Cache][Rack::Cache].

## Currently Supported Expressions

* `<esi:include src="..."/>` where `src` is a relative URL to be handled by the Rack application.
* `<esi:include src="..." alt="..." onerror="continue"/>` where `alt` is an alternative URL in case of error.
* `<esi:remove>...</esi:remove>`
* `<esi:comment text="..."/>`

## Examples

    rackup examples/basic_example_application.ru

With [Rack::Cache][]:

    rackup examples/basic_example_application_with_caching.ru

## TODOs and FIXMEs

    rake notes        # Show TODOs and FIXMEs
    rake notes:fixme  # Show FIXMEs
    rake notes:todo   # Show TODOs
