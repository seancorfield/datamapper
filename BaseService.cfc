/* copyright (c) 2011-2014 world singles llc
 *
 * base service providing support for legacy ORM APIs
 *
 * relies on other CFML services (not provided) to handle per-tier
 * environmnet settings, and Clojure services (not provided) via cfmljure
 * that provides the actual core persistence engine
 */
component {

	variables.formCache = { };
	
	// INJECTION POINTS
	
    public void function setClojure( any clojure ) {
        variables.clj = clojure;
        // simplify usage everywhere by allowing 'core' instead of variables.clj.clojure.core
        // and 'WS' instead of variables.clj.worldsingles so code is cleaner...
        core = variables.clj.clojure.core;
        WS = variables.clj.worldsingles;
    }


    public void function setEnvironmentService( any environmentService ) {
        variables.environmentService = environmentService;
    }
	
	
	public void function setORMService( any ormService ) {
		ORM = ormService;
	}
	
	
	public void function setSessionFacade( any sessionFacade ) {
		variables.sessionFacade = sessionFacade;
	}
	
	// PUBLIC METHODS
	
	public any function get( any id = 0 ) {
		if ( id == 0 ) {
			return ORM.create( variables.tableName );
		} else if ( structKeyExists( variables, 'cached' ) ) {
			var key = '_cache_' & variables.tableName & '_' & id;
			var cacheScope = local;
			// in case we want fancier caching:
			switch ( variables.cached ) {
			case 'application':
			case 'instance':
				cacheScope = variables;
				break;
			case 'session':
				// since we no longer use the real scope, we must cache into the session facade:
				if ( !variables.sessionFacade.has( key ) ) {
					var object = ORM.create( variables.tableName ).load( id );
					variables.sessionFacade.put( key, object );
				}
				return variables.sessionFacade.get( key );
				// not needed: break;
			default:
				if ( listFirst( variables.cached, ":" ) == "cache" ) {
					var name = listLast( variables.cached, ":" );
                    var object = WS.cache.fetch( key, name );
					if ( isSimpleValue( object ) ) {
						object = ORM.create( variables.tableName ).load( id );
						WS.cache.store( key, object, name );
					}
					return object;
				} else {
					// in case we're run in a thread and request scope doesn't exist:
					try {
						cachedScope = request;
					} catch ( any ex ) {
						cachedScope = local;
					}
				}
				break;
			}
			// in case we're run in a thread and the requested scope doesn't exist:
			try {
				if ( !structKeyExists( cacheScope, key ) ) {
					var object = ORM.create( variables.tableName ).load( id );
					try {
						// if this is invoked inside a thread, request scope doesn't exist so we will
						// fail to store the data in the request scope (and then just return the object)
						cacheScope[ key ] = object;
					} catch ( any ex ) {
						return object;
					}
				}
				return cacheScope[ key ];
			} catch ( any ex ) {
				return ORM.create( variables.tableName ).load( id );
			}
		} else {
			return ORM.create( variables.tableName ).load( id );
		}
	}
	
	public string function getTableName() {
		return variables.tableName;
	}
	
}
