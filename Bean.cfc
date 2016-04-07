/* copyright (c) 2011-2014 world singles llc
 *
 * I am actually an IBO - iterating business object - with ActiveRecord semantics.
 * In regular use, I am an ActiveRecord bean, but if you attach a resultset I become
 * an iterator with active count() / getNext() / hasMore() / reset() methods, as well
 * as getRecordCount() / resetIndex() aliases for legacy compatibility.
 */
component {
	
	// CONSTRUCTOR
	
	public any function init( string name, any clj, any orm ) {
		variables.name = name;
		variables.clj = clj;
        core = variables.clj.clojure.core;
        WS = variables.clj.worldsingles;
		variables.orm = orm;
		variables.iterator = false;
		variables._resetBean( false );
		// use the ORM to autowire myself:
		if ( structKeyExists( variables, "dependencies" ) ) {
			var services = listToArray( variables.dependencies );
			for ( var svc in services ) {
				variables.orm.injectBean( trim( svc ), variables );
			}
		}
		param name="variables.mongo" default="false";
		// see _keyGenPolicy() for details:
		variables.defaultKeyGenPolicy = core._identity();
		return this;
	}
	
	// PUBLIC METHODS
	
	// return a basic Clojure map for the object:
	public any function asClojure() {
		if ( isSimpleValue( variables.clojureMap ) ) {
			variables.clojureMap = WS.data.core.get_by_id( variables.clj.keyword( variables.name ), this.getId() );
			if ( !structKeyExists( variables, "clojureMap" ) ) {
				// no matching result - return empty map
				variables.clojureMap = core.hash_map();
			}
		}
		return variables.clojureMap;
	}
	
	
	// this turns me into an iterator:
	public any function attach( any resultSet ) {
		variables.resultSet = resultSet;
		variables.size = arrayLen( variables.resultSet );
		variables.position = 0;
		variables.iterator = true;
		return this;
	}
	
	
	public any function clone() {
		return variables.orm.create( variables.name )._cloneHelper( variables );
	}
	
	
	public numeric function count() {
		if ( variables.iterator ) {
			return variables.size;
		} else {
			throw "count() called when iterator is false";
		}
	}
	
	
	public any function delete() {
		if ( structKeyExists( variables.data, variables._pk() ) ) {
			WS.data.delete_by_id( variables.name, variables.data[ variables._pk() ] );
		}
		variables._resetBean( false );
		return this;
	}
	
	
	public struct function fullSlowMemento( boolean recurse = true ) {
		// used in just a few places to get a struct containing all (simple)
		// data in the object...
		var snapshot = { };
		structAppend( snapshot, variables.data );
		structAppend( snapshot, variables.dirty );
		for ( var f in this ) {
			if ( left( f, 3 ) == "get" && f != "get" ) {
				var key = right( f, len( f ) - 3 );
				try {
					snapshot[ "?" & key ] = this[ f ]();
				} catch ( any e ) {
					// ignore!
				}
			}
		}
		for ( var key in snapshot ) {
			if ( !isSimpleValue( snapshot[ key ] ) ) {
                if ( recurse &&
                     isStruct( snapshot[ key ] ) &&
                     structKeyExists( snapshot[ key ], "fullSlowMemento" ) ) {
                    snapshot[ key ] = snapshot[ key ].fullSlowMemento( false );
                } else {
				    structDelete( snapshot, key );
                }
			}
		}
		return snapshot;
	}
	
	
	public any function _get( string propertyName ) {
		if ( variables.isDirty && structKeyExists( variables.dirty, propertyName ) ) {
			return variables.dirty[ propertyName ];
		}
		if ( structKeyExists( variables.data, propertyName ) ) {
			return variables.data[ propertyName ];
		}
        if ( right( propertyName, 2 ) == "id" ) {
            // in the absence of a property that looks like an ID,
            // return a sensible default instead of an empty string
            return 0;
        }
		return "";
	}
	
	
	// this is mainly for legacy iterator support - note that the legacy code would
	// return the same beans from the array as you'd get from iterating through them
    // but this does not - it assumes you either iterate or you get the array, not both!
	public any function getArray() {
		if ( variables.iterator ) {
			var oldPosition = variables.position;
			this.reset();
			var beans = [ ];
			while ( this.hasMore() ) {
				arrayAppend( beans, this.getNext().clone() );
			}
			variables.position = oldPosition;
			return beans;
		} else {
			throw "getArray() called when iterator is false";
		}
	}
	
	
	// convenience to return 0 for missing id since we rely on that idiom a lot
	public any function getId() {
		if ( this._has( variables._pk() ) ) return this._get( variables._pk() );
		return 0;
	}
	
	
	public any function getNext() {
		if ( this.hasMore() ) {
			// behaves like load except it pulls from the resultSet
			variables.position++;
			variables._resetBean( true );
			variables.data = { };
			structAppend( variables.data, variables.resultSet[ variables.position ] );
			variables.loaded = structKeyExists( variables.data, variables._pk() );
		} else {
			throw "getNext() called when hasMore() is false";
		}
		return this;
	}
	
	
	// an alias for count() to help migration from legacy code
	public numeric function getRecordCount() {
		return this.count();
	}
	
	
	public boolean function _has( string propertyName ) {
		return structKeyExists( variables.dirty, propertyName ) || structKeyExists( variables.data, propertyName );
	}
	
	
	public boolean function hasMore() {
		return variables.iterator && variables.position < variables.size;
	}
	
	
	public any function load( any id ) {
		variables._resetBean( true );
		variables.data = { };
		structAppend( variables.data, WS.data.get_by_id( variables.name, id ) );
		variables.loaded = structKeyExists( variables.data, variables._pk() );
		return this;
	}
	
	
	public any function loadByKeys() {
		var args = { };
		structAppend( args, arguments );
		variables._resetBean( true );
		variables.data = { };
		var matches = WS.data.find_by_keys( variables.name, args );
		if ( arrayLen( matches ) ) {
			structAppend( variables.data, matches[1] );
			variables.loaded = structKeyExists( variables.data, variables._pk() );
		} else {
			// if there's no match, prepopulate the dirty fields with the keys:
			structAppend( variables.dirty, args );
			variables.isDirty = true;
			variables.loaded = true;
		}
		return this;
	}
	
	
	public any function nil( string propertyName ) {
		variables.dirty[ propertyName ] = WS.interop._null_value();
		variables.isDirty = true;
		variables.loaded = true;
		return this;
	}


    public any function populate() {
        for ( var arg in arguments ) {
            this.set( arg, arguments[ arg ] );
        }
        return this;
    }
	
	
	public any function reset() {
		if ( variables.iterator ) {
			variables.position = 0;
		} else {
			throw "reset() called when iterator is false";
		}
		return this;
	}
	
	
	// an alias for reset() to help migration from legacy code
	public any function resetIndex() {
		return this.reset();
	}
	
	
	public any function save( boolean reload = false ) {
		if ( !variables.loaded ) return;
		if ( structKeyExists( variables.data, variables._pk() ) && !structKeyExists( variables.dirty, variables._pk() ) ) {
			variables.dirty[ variables._pk() ] = variables.data[ variables._pk() ];
		}
		var id = WS.data.save_row( variables.name, variables.dirty, variables._keyGenPolicy() );
		if ( reload ) {
			this.load( id );
		} else {
			for ( var key in variables.dirty ) {
				variables.data[ key ] = variables.dirty[ key ];
			}
			variables.data[ variables._pk() ] = id;
			variables._cleanData();
		}
		return this;
	}
	
	
	public any function _set( string propertyName, any value ) {
		variables.dirty[ propertyName ] = value;
		variables.isDirty = true;
		variables.loaded = true;
		return this;
	}
	
	
	public string function type() {
		return variables.name;
	}
	
	
	public any function onMissingMethod( string missingMethodName, struct missingMethodArgs ) {
		var stem = left( missingMethodName, 3 );
		if ( stem == 'get' ) {
			var root = right( missingMethodName, len( missingMethodName ) - 3 );
			var n = len( root );
			var itPost = "iterator";
			var itLen = len( itPost );
			if ( n >= itLen && right( root, itLen ) == itPost ) {
				var startIndex = 1;
				if ( n == itLen ) {
					// getIterator("foo") or getIterator("foo",{ col = "asc|desc"}*)
					if ( structKeyExists( missingMethodArgs, 1 ) ) {
						var join = missingMethodArgs[ 1 ];
						root = join & "iterator";
						startIndex = 2;
					} else {
						throw "getIterator() requires the table name as an argument";
					}
				} else {
					// getFooIterator() or getFooIterator({ col = "asc|desc"}*)
					var join = lCase( left( root, n - itLen ) );
				}
				var orderInfo = { ordering = [] };
				var key = join & "iterator";
				if ( structKeyExists( missingMethodArgs, startIndex ) ) {
					orderInfo = variables._collectOrderBy( missingMethodArgs, startIndex );
					var key &= "|" & orderInfo.orderKey;
				}
                // #3607: we can cache the _data_ but must create the
                // iterator afresh on every "get" operation:
				if ( !structKeyExists( variables.relatedCache, key ) ) {
					var fk = { };
					fk[ variables.name & "Id" ] = this.getId();
					variables.relatedCache[ key ] = variables.orm.findByKeys( join, fk, "query", orderInfo.ordering );
				}
				return variables.orm.createIterator( join, variables.relatedCache[ key ] );
			}
			var join = root;
			var relatedConvention = true;
			if ( root == "related" ) {
				if ( structKeyExists( missingMethodArgs, 1 ) ) {
					// override default all lowercase name
					join = missingMethodArgs[ 1 ];
					relatedConvention = false;
				}
			}
			if ( !this._has( join ) ) {
				// not a known property, check for possible related object
				if ( this._has( join & "id" ) ) {
					var key = join & "related";
					if ( !structKeyExists( variables.relatedCache, key ) ) {
						var relatedId = this._get( join & "id" );
						if ( relatedConvention ) {
							join = lCase( root );
						}
						variables.relatedCache[ key ] = variables.orm.create( join ).load( relatedId );
					}
					return variables.relatedCache[ key ];
				}
			}
			return this._get( join );
		} else if ( stem == 'has' ) {
			var root = right( missingMethodName, len( missingMethodName ) - 3 );
			return this._has( root );
		} else if ( stem == 'set' ) {
			var root = right( missingMethodName, len( missingMethodName ) - 3 );
			if ( structKeyExists( missingMethodArgs, 1 ) ) {
				return this._set( root, missingMethodArgs[ 1 ] );
			} else {
				throw "#missingMethodName#() called without an argument";
			}
		} else if ( stem == "nil" ) {
			var root = right( missingMethodName, len( missingMethodName ) - 3 );
			return this.nil( root );
		} else {
			var message = "no such method (" & missingMethodName & ") in " & getMetadata(this).name & "; [" & structKeyList(this) & "]";
			throw "#message#";
		}
	}
	
	// PRIVATE METHODS
	
	private void function _cleanData() {
		variables.dirty = { };
		variables.clojureMap = 0;
		variables.relatedCache = { };
		variables.isDirty = false;
	}
	
	
	private any function _cloneHelper( struct cloneFrom ) {
		var cloneFields = [ "isDirty", "loaded" ];
		var cloneStructs = [ "data", "dirty" ];
		for ( var f in cloneFields ) {
			variables[ f ] = cloneFrom[ f ];
		}
		for ( var f in cloneStructs ) {
			variables[ f ] = { };
			structAppend( variables[ f ], cloneFrom[ f ] );
		}
		return this;
	}
	
	
	private struct function _collectOrderBy( struct args, numeric startIndex ) {
		var orderInfo = { ordering = [ ], orderKey = "" };
		while ( structKeyExists( args, startIndex ) ) {
			var arg = args[ startIndex ];
			if ( isStruct( arg ) && structCount( arg ) == 1 ) {
				var col = lCase( structKeyList( arg ) );
				var dir = lCase( arg[ col ] );
				if ( dir != "asc" && dir != "desc" ) {
					throw "getIterator() order arguments must be { column = asc|desc }";
				}
				var pack = { };
				pack[col] = dir;
				arrayAppend( orderInfo.ordering, pack );
				orderInfo.orderKey = listAppend( orderInfo.orderKey, col & ":" & dir );
			} else {
				throw "getIterator() order arguments must be { column = asc|desc }";
			}
			++startIndex;
		}
		return orderInfo;
	}
	
	
	private string function _pk() {
		return variables.mongo ? "_ID" : "ID";
	}
	
	
	// override this if you want to provide a custom key generation policy
	// the most likely alternative would be:
	//		return WS.data.uuid._add_uuid()
	private any function _keyGenPolicy() {
		return variables.defaultKeyGenPolicy;
	}
	
	
	private void function _resetBean( boolean loaded ) {
		variables.data = { };
		variables.loaded = loaded;
		variables._cleanData();
	}
	
}
