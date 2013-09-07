public with sharing class JSR {

	// Search the list of Apex Classes on fieldsToSearch, returning fieldsToReturn,
	// and requires that the class implements any specified interface
	@RemoteAction
	public static List<ApexClass> queryApexClasses(
		String interfaceName, 		// String, name of Interface that class must implement
		String searchText, 			// Space-separated, terms to search all search fields for 
		String fieldsToSearch, 		// Comma-separated, fields for SOQL query to search
		String fieldsToReturn		// Comma-separated, fields for SOQL query to return 
	) {
		
		if (searchText == null || searchText.trim() == '') return new List<ApexClass>();
		else {
			searchText = String.escapeSingleQuotes(searchText.trim());
		}
				
		// A list of field API Names to be searched		
		List<String> searchFields = split(fieldsToSearch,',',true);
		// A list of field API Names to be returned
		List<String> returnFields = split(fieldsToReturn,',',true);
		// A list of search terms to query each searchField for
		List<String> searchTerms;
		// If our search text contains a '.', e.g. 'relax.SwapSLAs',
		// then we should split up our search text, 
		// so that we match classes whose namespaceprefix is 'relax' and Name is 'SwapSLAs'.
		if (searchText.contains('.')) {
			searchTerms = searchText.split('\\.');
		} else searchTerms = split(searchText,' ',true);
        
        // If we have no searchTerms, then we cannot perform a query
        if (searchTerms == null || searchTerms.isEmpty()) return null;
        
        // Build a list of filter criteria based on the user's search terms
        List<String> searchFilters = new List<String>();
        
        if (searchTerms != null && !searchTerms.isEmpty()) {
        	for (String s : searchTerms) {
				searchFilters.add(' LIKE \'%' + s + '%\''); 
        	}
        }
        
        // Loop through our search fields and make sure that 
        // 1. We aren't searching on the Id field
        // 2. If the name field hasn't been added yet, add it
        if (searchFields != null) {
        	Boolean foundNameField = false;
        	for (String s : searchFields) if (s.equalsIgnoreCase('Name')) foundNameField = true;
			if (foundNameField == false) searchFields.add('Name');
        } else searchFields = new List<String>{'Name','NamespacePrefix'};	
        
        Set<String> fieldsToReturnByDefault = new Set<String>{
        	'Id',
        	'Name',
        	'NamespacePrefix'
        };
        
        // Begin building a Dynamic SOQL query
        String soql = 'SELECT Id, Name, NamespacePrefix';
        // If our list of fields to return is not empty, return these fields as well
        if (returnFields != null && !returnFields.isEmpty()) {
            for (String s : returnFields) {
            	if (!fieldsToReturnByDefault.contains(s)) soql += ', ' + s;
            }
        }
        // Add the object name
        soql += ' FROM ' + 'ApexClass' + ' ';
        
		// If we have more than one search term, 
		//	then we need to build parentheses-enclosed AND filters for EACH of the fields we want to search
		//
		// Example Search: we want to search Name and Group fields matching 'Hyacinth' AND '601'. Then we need the following SOQL:
		//	 SELECT Id, Name, Group FROM Account
        //	WHERE ((Name like hyacinth) or (Group like Hyacinth))
        //	AND ((Name like 601) or (Group like 601))
        // ORDER BY Name LIMIT 20
		
        for (Integer i = 0; i < searchFilters.size(); i++) {
        	// If this is the first search filter to be applied, use 'WHERE'.
        	// For all subsequent filters, use 'AND'
        	soql += ((i == 0) ? 'WHERE' : 'AND') + ' (';
        	// Loop through each field that needs to be searched, 
        	// and apply the current search filter to it
    		for (Integer j = 0; j < searchFields.size(); j++) {
    			// If we have more than one search term, separate them with 'OR' operators
    			soql += ((j != 0) ? ' or ' : '') + '(' + searchFields[j] + searchFilters[i] + ')';
    		}
        	soql += ')';
        }
        
        // Add in the ORDER BY and LIMIT clauses
        soql += ' ORDER BY Name LIMIT 20';
        
        // System.debug('***soql: ' + soql);
        
        List<ApexClass> lstClasses = new List<ApexClass>();
        try {
            lstClasses = (List<ApexClass>) Database.query(soql);
        } catch (QueryException e) {
            return lstClasses;
        }
        
        List<ApexClass> classesToReturn = new List<ApexClass>();
        
        // If we have ApexClasses returned,
        // see if they implement any specified interface
        if (!lstClasses.isEmpty()) {
        	if (interfaceName != null && interfaceName.trim() != '') {
        		// Loop over our Apex classes, seeing if they implement our specified interface
		        for (ApexClass cls : lstClasses) {
		            System.Type t;
		            try {
		                t = System.Type.forName(cls.NamespacePrefix,cls.Name);
		            } catch (Exception ex) { continue; }
		            //
		            // Schedulable interface...
		            //
		            if (interfaceName == 'Schedulable') {
			            Schedulable s;
			            try {
			                s = (Schedulable) JSON.deserialize('{}',t);
			            } catch (Exception ex) {}
			            if (s != null) {
			            	classesToReturn.add(cls);
			            }
		            } 
		            //
		            // Batchable Process Step
		            //
		            else if (interfaceName == 'ProcessStep') {
		            	// Ignore any abstract implementations of ProcessStep
			            if (!cls.Name.toLowerCase().contains('processstep')) {
				            ProcessStep s;
				            try {
				                s = (ProcessStep) JSON.deserialize('{}',t);
				            } catch (Exception ex) { continue; }
				            if (s != null) {
				                classesToReturn.add(cls);
				            }
			            }
		            } else {
		            	classesToReturn.add(cls);
		            } 
		        }
        	} else return lstClasses;
        }
        
        return classesToReturn;
   }   	  	
   
   // Attempt to split the given string into a comma-separated list of strings.
	// If the string has no commas, create a list of strings with a single entry.
	// Eliminate null entries, and optionally escape single quotes.
	public static List<String> split(String s, String delimiter, Boolean escapeSingleQuotes) {
		// If we are given nothing, return null
		if (s == null) return null;
		
		// Instantiate a list of parts
		List<String> parts;
		
		// Trim our string, and escape single quotes
		s = s.trim();
		if (escapeSingleQuotes) s = String.escapeSingleQuotes(s);
		
		// If our String is empty, return null 
		if (s == '') return null;
		
		//System.debug('*** s = \'' + s + '\'');
		
		// Attempt to split up our string based on commas
		if (s.indexOf(delimiter) != -1) {
			// Our string has a comma somewhere in it, so use the comma to split up the string
			try {
				parts = s.split(delimiter);
			} catch (Exception ex) {
				System.debug('Caught ' + ex.getTypeName() + ' trying to split up our string: ' 
					+ ex.getMessage() + '. ' 
					+ ex.getStackTraceString());
				return null;
			}
		} else {
			// We could not find a comma. Instantiate a list with s as its sole entry.
			parts = new List<String>{s};
		}
        
        if (parts.isEmpty()) return null;
        
        // Loop backward through our 'field' strings to eliminate null entries
        // If they do not, remove them from our list
        for (Integer i = parts.size() - 1; i >= 0; i--) {
        	String f = parts[i].trim();
        	if (f == '') parts.remove(i);
        	else parts[i] = f;
        }
   		return parts;
	} 
   
} // end class