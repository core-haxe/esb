# esb

(For nodejs)

ESB stands for enterprise service bus (ESB).  It is a communication system for a service oriented architecture. It is a variant of the more general client-server model. where every service can have both a server role *producer*  as well as client role *consumer*.

The principle of the ESB are the following
-  Services communicate via *messages*.
-  Messages are handled in a async way and go through a *queue*.
It means that if any service goes down for any reason, nothing is lost, and when things start again, everything just picks up from where it left off.
ESB uses rabbit-mq.
-  Each service contains logic to integrate the message: transformation, routing, ...


## Creating and registering a bundle 

To create and register a bundle you need to create a json file and place it in the main ESB config dir ( this is done automatically by haven). It will enable the ESB to know which file to load.


### JSON config overview

```json
{
    "bundles": {
        "bundle-test": {
            "name": "bundle-test",
            "bundle-file": "bundle-test",
            "bundle-entry-point": "bundles.test.Bundle",
            "auto-start": true,
            "disabled": false,
            "routes": {
                ...
            },
            "prefixes": {
                ...
            },
            "dependencies": {
                "bundle-test2": {
                    "disabled": false
                }
            },
            "properties": {
            },
            
        }
    }
}
```
`name`  the name of the bundle. It is is useful as bundle are referenced by name in the dependencies.

`bundle-file`  the name of the js file ( ending with .js or not), which will be loaded by the ESB

`bundle-entry-point`  the class entry that must extend `esb.core.Bundle``

`auto-load`  whether the bundle will be automatically loaded  when the ESB is run

`auto-start`  whether the bundle will be automatically started when the ESB is run. If it's a true, it also automatically load the bundle.
It will call the function named `start` in the entry points

`disabled` 

`dependencies`

`properties`

`routes` where you register routes

`prefixes` where you register URI prefixes


## Message transformation

A bundle can contain services that transform a message into another message.

For example, `esb-bundle-xlsx` accepts an xlsx message body as as incoming format  and can convert them into a CSV message body

### Registering the accepted body type of the bundle 

It needs to register Message Type with the `registerMessageType` function.  It will basically register the message *body* type to the ESB, so that bus knows that this bundle is the one that consume (is recipient) these messages.

```haxe
registerMessageType(bundles.xlsx.bodies.XlsxBody, () -> {
            var m = @:privateAccess new Message<bundles.xlsx.bodies.XlsxBody>();
            m.body = new bundles.xlsx.bodies.XlsxBody();
            return cast m;
        });
```



### Registering the body type transformations
 
It can also register the message transformations with `registerBodyConverter`

For example, `esb-bundle-xlsx` registers the `xlsx` to `csv` converter.
```haxe
registerBodyConverter(bundles.xlsx.bodies.XlsxSheet, CsvBody, (sheet) -> {
            var firstRow = null;
            var csv = new CsvBody();
            for (row in sheet.rows()) {
                if (firstRow == null) {
                    firstRow = row;
                    csv.addColumns(firstRow);
                } else {
                    csv.addRow(row);
                }
            }
            return csv;
        });
```


## Routing

A bundle can also define routes. Routes guides messages through different services from a starting point to an ending point.
The starting point and ending points are URI Uniform Resource Identifier.

### Registering routes to the ESB with the json config

You register the routes in the json config.

```json
{
    "bundles": {
        "bundle-test": {
            ...
            "routes": {
                "check-folder": {
                    "class": "bundles.test.routes.CheckFolder"
                }
            },
        }
    }
}
```

### Example of a route


Here's a route that check if there are zip files is a specific folder and unzips them in another folder.

```haxe
    new Route(routeContext)
            .from("file://{{download.path}}?pattern=*.zip&renameExtension=complete&pollInterval=5000")
            .log("found temporaris hr zip file")
            .convertTo(ZipBody)
            .loop(_(body.entries))
                .property("file.name", _(body.name))
                .property("file.extension", _(body.extension))
                .property("file.hash", _(body.hash))
                .log("extracted file from zip  to '${body.name}.${body.extension}'")
                .body(_(body.data), RawBody)
                .to("file://{{unzipfolder.path}}?filename={file.name}-{file.hash}.{file.extension}")
            .end()
        .start();
```

The Route has a defined starting point ".from"  and has a defined ending point  ".to"

The route is described with the HPEL ( Haxe Process Execution Language) DSL  .


## Creating new URIs


### Registering the URIs to the ESB in  the JSON config.


Here is the how the prefix `file`` that was used in a route URI `.from("file://{{download.path}}?pattern=*.zip&renameExtension=complete&pollInterval=5000")`
is registered.

```json
{
    "bundles": {
        "bundle-test": {
            ...
            "prefixes": {
                "file": {
                    "consumer": {
                        "class": "esb.bundles.core.files.FileConsumer"
                    },
                    "producer": {
                        "class": "esb.bundles.core.files.FileProducer"
                    }
                }
            },
        }
    }
}
```

There are two files needed. One as a *consumer*, and another as *producer*.
The *consumer* will be used as the ending point of a route `.to()`
The *producer* will be used as the staring point of a route `.from()`

Remember that *consumer* and *producer* is from the point of view of the service.
`.from`  produces a new message which is consumed when it goes through `to`
(It is not, the one that creates a new file is a producer)
