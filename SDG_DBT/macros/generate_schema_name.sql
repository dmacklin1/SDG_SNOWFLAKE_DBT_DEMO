{#
    Use the schema configured in dbt_project.yml verbatim.
    Default dbt behaviour concatenates target.schema + custom schema
    (e.g. SOURCE_A becomes DEV_SOURCE_A). This override turns that off so
    the schema names in dbt_project.yml are exactly what lands in Snowflake.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
