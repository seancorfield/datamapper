datamapper
==========

A couple of CFCs from the World Singles data mapper to show how we wrap Clojure (vectors of) hashmaps to present a thin OO veneer to our CFML code.

Presented as GPLv3 code so you can't incorporate this into your code unless your code is also open source under GPLv3!

The Service CFC is injected into all of our code as variables.orm. Most of our service CFCs extend the BaseService CFC to provide basic cached get() for entities (I've chopped a lot of other stuff out of this CFC).

The Bean CFC is an Iterating Business Object wrapper around an array of structs which represent rows in the database. Our specific business objects extend this so they can add business logic and override specific get/set operations if needed.

When you do orm.create("foo"), it'll use ws/model/orm/beans/foo.cfc if it exists (which extends Bean) or else it'll fall back to Bean itself. It is assumed the associated table name is "foo".

This also allows us to "attach" an IBO to any data set and treat it as a specific business object. We do this to allow a joined data set to be viewed as both a set of users and as a set of messages for example, when we have joined across those two tables. You can also attach a generic IBO to an arbitrary data set and that provides get/set methods.

The Bean supports foo.getBar() where foo contains barid and thats an FK to bar.id and it will lazy load a "bar" object - many-to-one relationship. Similarly foo.getQuuxIterator() will use quux.fooid to lazy load a one-to-many relationship.
