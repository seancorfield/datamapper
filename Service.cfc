/* copyright (c) 2011-2014 world singles llc
 *
 * ORM service providing create bean/iterator and execute SQL APIs
 */
component {
	
	// CONSTRUCTOR
	
	public any function init( any clj ) {
		variables.clj = clj;
        WS = variables.clj.worldsingles;
		variables.cfcExists = { };
		variables.beanPath = expandPath( "/ws/model/orm/beans" );
        variables.beanCache = { };

        // executeCount assumes SELECT COUNT(*) FROM ...
        var core = variables.clj.clojure.core;
        this.executeCount = core.comp(
            core._first(),
            core._vals(),
            core._first()
        );
		return this;
	}
	
	// INJECTION POINTS
	
	public void function setBeanFactory( coldspring.beans.BeanFactory factory ) {
		variables.beanFactory = factory;
	}
	
	// PUBLIC METHODS
	
	public any function create( string name ) {
		if ( !structKeyExists( variables.cfcExists, name ) ) {
            // just in case we're passed a dotted name, look for a bean in
            // a subfolder:
			var filePath = variables.beanPath & "/" &
                replace( name, ".", "/", "all" ) & ".cfc";
			variables.cfcExists[ name ] = fileExists( filePath );
		}
		if ( variables.cfcExists[ name ] ) {
			var beanName = "ws.model.orm.beans." & name;
			return new "#beanName#"( name, variables.clj, this );
		} else {
			return new ws.model.orm.Bean( name, variables.clj, this );
		}
	}
	
	
	// createIterator( tableName, resultSet ) or
	// createIterator( name = tableName, sql = "..." [, params ] )
	public any function createIterator( string name, any data = 0, string sql = "", array params = [ ] ) {
		var bean = this.create( name );
		if ( !isSimpleValue( data ) ) {
			bean.attach( data );
		} else if ( len( sql ) ) {
			bean.attach( execute( sql, params ) );
		} else {
			throw "createIterator() requires data or sql";
		}
		return bean;
	}
	
	
	public any function execute() { // sql-string, params = [ ], transform = #(doall (map cfml/to-struct %)) 
		return WS.data.execute( argumentCollection = arguments );
	}
	
	// technically the format is array of structs, not query!
	public any function findByKeys( string name, struct args, string format = "query", array orderBy = [ ] ) {
		var result = WS.data.find_by_keys( name, args, orderBy );
		if ( format == "iterator" ) {
			result = this.createIterator( name, result );
		}
		return result;
	}


	public void function injectBean( string beanName, struct scope ) {
        if ( !structKeyExists( variables.beanCache, beanName ) ) {
		    variables.beanCache[ beanName ] = variables.beanFactory.getBean( beanName );
        }
		scope[ beanName ] = variables.beanCache[ beanName ];
	}
	
    
    public any function asValueList( string column ) {
        return WS.data.mapping.value_list( column );
    }

    public any function queryToResultSet( query q ) {
        // return array of structs instead
        var rows = [ ];
        for  ( var row in q ) {
            rows.append( row );
        }
        return rows;
    }

}
