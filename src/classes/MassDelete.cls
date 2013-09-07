global class MassDelete extends BatchableSchedulableProcessStep implements Database.Stateful {

	global String parameters;

	public String query;

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
			} catch (Exception ex) {
				// Complete our batch process
				complete();
				throw ex;
			}	
			
		}
		
		if (query != null) {
			return Database.getQueryLocator(query);
		} else {
			// Return a dummy query locator
			return Database.getQueryLocator([select Id from User where Id = :UserInfo.getUserId() limit 0]);
			
		}	
	}
	
	global override void execute(Database.BatchableContext btx, List<SObject> scope) {
		if (scope != null && !scope.isEmpty()){
			Database.delete(scope,false);
		}	
	}
	
	global override void finish(Database.BatchableContext btx) {
		// Continue our Batch Process, if we need to
		complete();
	}
	
	// Implements Schedulable interface
	global override void execute(SchedulableContext ctx) {
		Database.executeBatch(new MassDelete());
	}

}