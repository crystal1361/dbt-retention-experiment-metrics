{#
    Fails when any combination of `columns` appears more than once.
    Written in-project (instead of pulling dbt_utils) to keep the build
    dependency-free and to show how custom generic tests work.
#}
{% test unique_combination(model, columns) %}

select
    {{ columns | join(', ') }},
    count(*) as n_rows
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
