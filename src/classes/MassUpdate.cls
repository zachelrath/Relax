global class MassUpdate extends BatchableSchedulableProcessStep implements Database.Stateful {

	global String parameters;

	public String query, 
			sourceField, 
			targetField;
	public Object value;
	
	public Map<String,Object> valuesByField,
			sourceFieldsByTargetField; 
	
	public String mode;

	global override Database.QueryLocator start(Database.BatchableContext btx){
		
		// Attempt to retrieve parameters from our Job record
		// if we do not have parameters yet.
		if (parameters == null) parameters = params();
		if (parameters != null) {
			// We expect our parameters to be a JSON object,
			// so deserialize it
			Map<String,Object> paramsObj;
			try {
				paramsObj = (Map<String,Object>) JSON.deserializeUntyped(parameters);
				query = (String) paramsObj.get('query');
				mode = (String) paramsObj.get('mode');
				// Default mode is 'Field from Field'
				if (mode != null) {
					
					// Retrieve appropriate parameters
					// depending on what mode we are dealing with
					
					// FIELD_WITH_VALUE
					// For each record retrieved in the query,
					// update the specified field
					// with the specified value.
					if (mode.equalsIgnoreCase('FIELD_WITH_VALUE')) {
						targetField = (String) paramsObj.get('field');
						value = paramsObj.get('value');
					} 
					
					// FIELDS_WITH_VALUES
					// For each record retrieved in the query,
					// update the specified fields
					// with corresponding values
					else if (mode.equalsIgnoreCase('FIELDS_WITH_VALUES')) {
						valuesByField = (Map<String,Object>) paramsObj.get('valuesByField');
					} 
					
					// FIELD_FROM_FIELD
					// For each record retrieved in the query,
					// update the specified targetField
					// with the value of the row's corresponding sourceField 
					else if (mode.equalsIgnoreCase('FIELD_FROM_FIELD')) {
						sourceField = (String) paramsObj.get('sourceField');
						targetField = (String) paramsObj.get('targetField');
					}
					
					// FIELDS_FROM_FIELDS
					// For each record retrieved in the query,
					// update each provided field with the value of another corresponding field.
					else if (mode.equalsIgnoreCase('FIELDS_FROM_FIELDS')) {
						sourceFieldsByTargetField = (Map<String,Object>) paramsObj.get('sourceFieldsByTargetField');
					}
					
					query = (String) paramsObj.get('query');
					
				}	
			} catch (Exception ex) {
				// Complete our batch process
				complete();
				throw ex;
			}	
			
		}
		
		if ((query != null) && (mode != null)) {
			return Database.getQueryLocator(query);
		} else {
			// Return a dummy query locator
			return Database.getQueryLocator([select Id from User where Id = :UserInfo.getUserId() limit 0]);
			
		}	
	}
	
	global override void execute(Database.BatchableContext btx, List<SObject> scope) {
		
		for (Sobject so : scope) {
			//try {
				if (mode.equalsIgnoreCase('FIELD_WITH_VALUE')) {
					so.put(targetField,value);
				} else if (mode.equalsIgnoreCase('FIELD_FROM_FIELD')) {
					so.put(targetField,so.get(sourceField));
				} else if (mode.equalsIgnoreCase('FIELDS_WITH_VALUES')) {
					for (String field : valuesByField.keyset()){
						so.put(field,valuesByField.get(field));
					}
				} else if (mode.equalsIgnoreCase('FIELDS_FROM_FIELDS')) {
					for (String targetField : sourceFieldsByTargetField.keyset()){
						so.put(
							// Target field
							targetField, 
							// Value of source field on this row
							so.get( 
								String.valueOf(
									sourceFieldsByTargetField.get(targetField)
								)
							)
						);
					}
				}	
			//} catch (Exception ex) {
				// TODO: send detailed error messages
				// with the results of each operation
				
			//}
		}
		Database.update(scope,false);
	}
	
	global override void finish(Database.BatchableContext btx) {
		// Continue our Batch Process, if we need to
		complete();
	}
	
	// Implements Schedulable interface
	global override void execute(SchedulableContext ctx) {
		Database.executeBatch(new MassUpdate());
	}

}