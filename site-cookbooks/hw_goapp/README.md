hw_goapp Cookbook
===============
This cookbook ensures that go apps are running by creating and enabling services for them

Requirements
------------
#### packages
- `golang`

Attributes
----------

None, though you do need to define node['go']['packages'] and node['go']['owner']

Usage
-----
#### hw_goapp::default
Just include `hw_goapp` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[hw_goapp]"
  ]
}
```

License and Authors
-------------------
Authors: cvlc <c@cypher.cc>
