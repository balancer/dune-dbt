{#
    profiles.yml is used to set environments, target specific schema name:
        - --target prod: <team_name>
        - --target dev, no DEV_SCHEMA_SUFFIX value set: <team_name>__tmp_
        - --target dev, DEV_SCHEMA_SUFFIX value set: <team_name>__tmp_<DEV_SCHEMA_SUFFIX>
            --note: in CI workflow, DEV_SCHEMA_SUFFIX is set to PR_NUMBER
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {# Base schema is set in profiles.yml per Dune docs (team or team__tmp_*) #}
    {%- set base_schema = target.schema -%}

    {# If a model supplies a custom schema, append it to avoid collisions #}
    {%- if custom_schema_name is not none -%}
        {{ base_schema }}__{{ custom_schema_name | trim }}
    {%- else -%}
        {{ base_schema }}
    {%- endif -%}

{%- endmacro %}
