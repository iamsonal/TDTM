
/**
* @author Salesforce.org
* @date 2015
* @group TDTM
* @group-content ../../ApexDocContent/TDTM.htm
* @description Allows running TDTM class only for those records that do not meet the filtering criteria.
* Those that do are taken out from the list of records to process. 
*/
public class TDTM_Filter {
    
    /* @description  Information on the class being run.*/
    TDTM_Global_API.TdtmToken tdtmToken;
    /* * @description The records that were passed to the trigger as trigger.new. */
    List<SObject> newList;
    /* @description The records that were passed to the trigger as trigger.old. */
    List<SObject> oldList;
    /* @description The type of SObject the class runs for. */
    DescribeSObjectResult describeObj;
    /* @description filterField The field to filter on, including the whole relationship chain, i.e. "Account.Name".*/
    String filterField;
    /* The field to filter on in the parent object, i.e. "Name". */
    String fieldName;
    /* @description The value to compare against when filtering, already in the correct type. */
    Object filterValue;
    /* @description An instance of the wrapper object that contains the filtered newList and oldList. */
    FilteredLists filtered;
    /* @description The chain of parent objects used in the filter, not including the object the class is running on. 
    i.e., if the class runs on Contact this could be "Account", and if it runs on Opportunity "Contact.Account"*/
    List<String> filterObjectChain;
    
    /*******************************************************************************************************
    * @description Constructor. Sets properties.
    * @param classToRunRecord The class being run.
    * @param newList The records that were passed to the trigger as trigger.new.
    * @param oldList The records that were passed to the trigger as trigger.old.
    * @param describeObj The type of SObject the class runs for.
    */
    public TDTM_Filter(TDTM_Global_API.TdtmToken tdtmToken, List<SObject> newList, List<SObject> oldList, 
    DescribeSObjectResult describeObj) {
        this.tdtmToken = tdtmToken;
        this.newList = newList;
        this.oldList = oldList;
        this.describeObj = describeObj;
        filtered = new FilteredLists();
        filterObjectChain = new List<String>();
    }
    
    /*******************************************************************************************************
    * @description Filters records to process.
    * @return FilteredLists An instance of the wrapper object that contains the filtered newList and oldList.
    */
    public FilteredLists filter() {
        try {
            filterField = tdtmToken.filterField;
            if(filterField != null) {
                if(filterField.contains('.')) { 
                    filterByRelationship();
                } else {
                    fieldName = filterField;
                    filterByField();
                }
                return filtered;
            }
        } catch(Exception e) {
        }
        return null;
    }
    
    /*******************************************************************************************************
    * @description Filters newList and oldList based on the value of a related field.
    * @return void 
    */
    private void filterByRelationship() {        
        List<SObject> newListRelatedFields = queryRelatedFields(newList);
        
        List<String> filterFullChain = (filterField.split('\\.', 0)); //separate cross object references, i.e. account.name   
        fieldName = filterFullChain[filterFullChain.size() - 1]; //get the field name itself
        String parentObjectName = filterFullChain[filterFullChain.size() - 2]; //get the name of the field parent = last object in the chain
        
        //remove the field, to have only the parent object chain
        for(Integer i = 0; i < (filterFullChain.size() - 1); i++)
            filterObjectChain.add(filterFullChain[i]);
        
        //For the special Parent field on Account case. The relationship is called "Parent", but the object is Account.
        if(filterFullChain.size() > 2 && filterFullChain[filterFullChain.size() - 3]  == 'Account' && filterFullChain[filterFullChain.size() - 2] == 'Parent') {
            parentObjectName = 'Account'; //If we don't do this, we get "Exception: Invalid object name 'Parent'" when calling getObjectDescribe, because the 
            //element in the map retrieved from the parent is ParentId.
        }
        
        SObjectField field = getSObjectFilterField(parentObjectName);
        
        if(field != null) { //the field name is valid for the object at the top of the chain!
            filterValue = getFilter(field);
            filterByCondition(newListRelatedFields);
        } else {
            addErrorToAll();
        }       
    }
    
    /*******************************************************************************************************
    * @description Adds an error message to all the records in the trigger.
    * @return void
    */
    private void addErrorToAll() {
        for(Integer i = 0; i < newList.size(); i++) {
            newList[i].addError(tdtmToken.className);
            filtered.newList.add(newList[i]);
        }
    }
    
    /*******************************************************************************************************
    * @description We need the SObjectField to know the type of the filter field and determine if any manipulation 
    * is necessary. All the filter conditions are stored as strings, but some many need to be transformed to 
    * compare against the values in the trigger records. For example, is a filtering condition is stored as 'true' 
    * we'll need to transform it into the Boolean value true.
    * @param parentObjectName The name of the object that is the parent of the filter field, as initially defined in the filtering
    * condition.
    * @return SObjectField The field to filter on as SObjectField.
    */
    private SObjectField getSObjectFilterField(String parentObjectName) {
        SObjectField field = getSOField(parentObjectName, fieldName);
        
        if(field == null) {
            //If the field is not valid, go up the object chain until we find one that is valid. Then go back down to find the object type
            //at each level, until we get to the type of the parent of the filter field.
            ChainLink firstValidLink = findValidObjectInChain(filterObjectChain.size() - 1);
            //Now go back down the chain. What we really want is the object type of the parent of the filter field.
            ChainLink link = firstValidLink;
            for(Integer i = firstValidLink.objectChainIndex + 1; i < filterObjectChain.size(); i++) {
                field = getSOField(link.objectReferenced, filterObjectChain[i]);
                String objectReferenced = getObjectTypeReferenced(link.objectReferenced, filterObjectChain[i]);
                link = new ChainLink(field, objectReferenced, link.objectReferenced, i);
            }
            field = getSOField(link.objectReferenced, fieldName);
        }
        return field;
    }
    
    /*******************************************************************************************************
    * @description Finds the first valid object in the chain, that is the first item in the chain built from the filtering
    * condition where the name is an actual object name. If none of the items in the chain are an actual object, it will 
    * go all the way back up to the object the class is running on.
    * @objectChainIndex The index of the element in the chain to inspect.  
    */
    private ChainLink findValidObjectInChain(Integer objectChainIndex) {
        SObjectField field;
        if(objectChainIndex == 0) {
            String topParent = describeObj.getName();
            field = getSOField(topParent, filterObjectChain[objectChainIndex]);
            String objectReferenced = getObjectTypeReferenced(describeObj.getName(), filterObjectChain[objectChainIndex]);
            ChainLink link = new ChainLink(field, objectReferenced, describeObj.getName(), objectChainIndex);
            return link;
        } else {
            String child = filterObjectChain[objectChainIndex];
            String parent = filterObjectChain[objectChainIndex -1];
            String objectReferenced = getObjectTypeReferenced(parent, child);
            if(parent != null) {
                field = getSOField(parent, child);
                if(field == null) {
                    return findValidObjectInChain(--objectChainIndex);
                } else {
                    ChainLink link = new ChainLink(field, objectReferenced, parent, objectChainIndex);
                    return link;
                }
            } else {
                return findValidObjectInChain(--objectChainIndex);
            }
        }
    }
    
    /*******************************************************************************************************
    * @description Get the object type of the filter field. For example, the field might be called Current_Address__c, 
    * but the object is Address__c.
    * @param parent The parent object of the field.
    * @param child The field for which we are trying to find the object type referenced.
    * @return String The name of the object referenced by child, if any. 
    */
    private String getObjectTypeReferenced(String parent, String child) {
        String objPointingTo;
        DescribeSObjectResult objectDescribe;
        try {
            parent = fromRtoC(parent);
            child = fromRtoC(child);
            objectDescribe = UTIL_Describe.getObjectDescribe(parent);
            if(objectDescribe != null) {
                Map<String, SObjectField> fieldsMap = objectDescribe.fields.getMap();
                DescribeFieldResult customObjParentDescribe = fieldsMap.get(child).getDescribe();
                List <sObjectType> refs = customObjParentDescribe.getReferenceTo();
                if(refs != null && refs.size() == 1) {
                    objPointingTo = refs[0].getDescribe().getName();
                } else if(refs.size() > 1) {
                }
            }
        } catch(UTIL_Describe.SchemaDescribeException e) {
            return null;
        }
        return objPointingTo;
    }
    
    /*******************************************************************************************************
    * @description Gets the SObjectField for the fieldName field name in parentObjectName.
    * @param parentObjectName The name of the object containing the field, as a string.
    * @param fieldName The name of the field we are looking for, as a string.
    * @return SObjectField The field we are looking for.
    */
    private SObjectField getSOField(String parentObjectName, String fieldName) {
        parentObjectName = fromRtoC(parentObjectName);  
        fieldName = fromRtoC(fieldName);

        try {
            return getSOFieldHelper(parentObjectName, fieldName);
        } catch(UTIL_Describe.SchemaDescribeException e) {
            //Fix the relationship filter here (If the parent chain in the relationship includes user's custom object, then the filter does not work)
            //Example: Say we have a filter Account.MyObj__r.MyField__c on Contact object (MyObj__r and MyField__c are user's object/field)
            //This filter won't work because fromRtoC method will add namespace to MyObj__r and MyField__c.
            //Adding extra EDA namespace to the field (e.g. MyField__c) is ok because objectDescribe.fields.getMap().get(xxx) will ignore extra EDA namespace
            //Adding extra EDA namespace to the object (e.g. MyObj__c) is NOT because UTIL_Describe.getObjectDescribe(xxx) expect the exact api name
            //The fix here is not ideal but it is safer than making a big change in fromRtoC method that has the risk to break other use cases
            try {
                return getSOFieldHelper(parentObjectName, fieldName);
            } catch (UTIL_Describe.SchemaDescribeException ex) {
                return null;
            }
        }
    }

    /*******************************************************************************************************
    * @description The helper method that returns the SObjectField based on object name and field name
    * @param parentObjectName The name of the object containing the field, as a string.
    * @param fieldName The name of the field we are looking for, as a string.
    * @return SObjectField The field we are looking for.
    */
    private SObjectField getSOFieldHelper(String parentObjectName, String fieldName) {
        DescribeSObjectResult objectDescribe = UTIL_Describe.getObjectDescribe(parentObjectName);
        if(objectDescribe != null) {
            Map<String, SObjectField> fieldsMap = objectDescribe.fields.getMap();
            return fieldsMap.get(fieldName);
        } else {
            return null;
        }
    }
    
    /*******************************************************************************************************
    * @description Replaces __r with __c in the string passed, in case that's the only difference between the name
    * used to query and the actual object named referenced. It also adds the package prefix, if necessary.
    * @param The relationship name.
    * @return String The object name, if the name of a custom relationship was passed. 
    */
    private String fromRtoC(String fieldName) {
        //Remove custom field/object suffix
        if(fieldName.endsWith('__r') || fieldName.endsWith('__c')) {
            String suffix;
            if(fieldName.endsWith('__r')) {
                suffix = '__r';
                fieldName = fieldName.removeEnd('__r');
            }
            else if(fieldName.endsWith('__c')) {
                suffix = '__c';
                fieldName = fieldName.removeEnd('__c');
            }
            //Add prefix ONLY IF it hasn't already been added
//            if(!fieldName.contains('__'))
//                fieldName = UTIL_Namespace.StrTokenNSPrefix(fieldName);
            //Put suffix back
            fieldName = fieldName + suffix;
        }
        
        if(fieldName.endsWith('__r'))
            return fieldName.replace('__r', '__c');
        else
            return fieldName;
    }
    
    /*******************************************************************************************************
    * @description Queries the fields that are part of the relationship filter, since these values are not initially
    * present in the records the triggers acts on.
    * @param compList The list of records to query.
    * @return List<SObject> A list of records pointing to the same records that are present in newList or oldList,
    * but containing only the fields defined in the query condition. The returned list is also in the same order as 
    * newList or oldList.
    */
    private List<SObject> queryRelatedFields(List<SObject> compList) {
        List<SObject> withRelatedFields = new List<SObject>(); //We don't want to modify the original list, but use a new one instead.
        if(compList != null) {
	        Map<ID, SObject> compMap = new Map<ID, SObject>(compList);
	        Set<ID> compListIDs = compMap.keySet();
	        //query filter values, in case they are not in the trigger
	        String dynamicQuery = 'select ' + String.escapeSingleQuotes(filterField) + ' from ' + String.escapeSingleQuotes(describeObj.getName()) +  ' where ID in :compListIDs';
	        Map<ID, SObject> withRelatedFieldsMap = new Map<ID, SObject>(Database.query(dynamicQuery));
	        //Let's make sure we return them in the same order as the list passed as param
	        for(SObject compRecord : compList) {
	            withRelatedFields.add(withRelatedFieldsMap.get(compRecord.ID));
	        }
        }
        return withRelatedFields;
    }
    
    /*******************************************************************************************************
    * @description Filters newList and oldList based on the value of a field on the trigger records.
    * @return FilteredLists An instance of the wrapper object that contains the filtered newList and oldList. 
    */
    private void filterByField() {
        //get field type
        SObjectField field = describeObj.fields.getMap().get(fieldName);
        if(field != null) { //the field name is valid!
            filterValue = getFilter(field);
            filterByCondition(null);
        } else {
            addErrorToAll();
        }
    }
    
    /*******************************************************************************************************
    * @description Returns the value to compare against in the correct type.
    * @param Field The SObjectField used in the filtering comparison.
    * @return Object The value to compare against when filtering, already in the correct type. 
    */
    private Object getFilter(SObjectField field) {
        //let's find the field type
        DisplayType fieldType = field.getDescribe().getType();
        String val = tdtmToken.filterValue;    
        if(fieldType == DisplayType.Boolean) {
            if(val == 'true') {
                return true;
            } else if(val == 'false') {
                return false;
            }
        } else if(fieldType == DisplayType.Date) {
            return Date.parse(val);
        } else if(fieldType == DisplayType.Reference) {
            return ID.valueOf(val);
        } else if(fieldType == DisplayType.CURRENCY) {
            return Decimal.valueOf(val);
        } else if(fieldType == DisplayType.INTEGER) {
            return Integer.valueOf(val);
        } else if(fieldType == DisplayType.DOUBLE) {
            return Double.valueOf(val);
        } else if(fieldType == DisplayType.PERCENT) {
            return Decimal.valueOf(val);
        } else { //We'll treat everything else as a string, including String, Email, Phone, and Picklist
            return val;
        }
        return null;
    }

    /*******************************************************************************************************
    * @description Filters newList and oldList based on the defined filtering criteria. 
    * @param newListRelatedFields A list of records pointing to the same records that are present in newList, 
    * but containing only the fields defined in the query condition. In the same order as newList.
    * @return void 
    */
    private void filterByCondition(List<SObject> newListRelatedFields) {
        if(filterObjectChain.size() == 0) { //The field in in the same object the trigger fires on
            //Only need newList to decide if a record meets trigger handler filter value
            filterList(newList, newList, filtered.newList);
            filterList(oldList, newList, filtered.oldList);
        } else { //The field is in a related object
            filterListByRelatedField(newListRelatedFields, newList, filtered.newList);
            //Only need newListRelatedFields to decide if a record meets trigger handler filter value
            filterListByRelatedField(newListRelatedFields, oldList, filtered.oldList);
        }
    }
    
    /*******************************************************************************************************
    * @description Populates filteredList with the records from originalList that don't match the filtering
    * criteria included in listRelatedFields. Used for filtering criteria based on a relationship.
    * @param listRelatedFields A list of records pointing to the same records that are present in originalList, 
    * but containing only the fields defined in the query condition. In the same order as originalList.
    * @param originalList The original list whose records not matching the filter criteria will be added to 
    * the resulting filtered list.
    * @param filteredList The resulting filtered list.
    * @return void 
    */
    private void filterListByRelatedField(List<SObject> listWithRelatedFields, List<SObject> originalList, 
    List<SObject> filteredList) {
        if(listWithRelatedFields != null && listWithRelatedFields.size() > 0) {
            for(Integer i = 0; i < listWithRelatedFields.size(); i++) {
                SObject o = listWithRelatedFields[i];
                Boolean addDirectly = false;
                //traverse parent relationships until the last one
                if (o != null) { //if the object at the bottom of the chain (the one in the trigger) isn't null
                    for (String parentObj : filterObjectChain) {
                        if(o != null) { //if each following object in the chain isn't null
                            o = o.getsObject(parentObj);
                        } else {
                            addDirectly = true;
                            break;
                        }
                    }
                    
                }
                //in case the topmost object in the chain is null
                if(o == null) {
                    addDirectly = true;
                }
                //perform the filtering
                if(addDirectly || (o != null && o.get(fieldName) != filterValue)) {
                    filteredList.add(originalList[i]);
                }
            }
        }
    }
    
    /*******************************************************************************************************
    * @description Populates filteredList with the records from listToFilter that don't match the filtering
    * criteria.
    * @param listToFilter The list of records to filter.
    * @param newList The list of new records to compare with filter value.
    * @param filteredList The resulting filtered list.
    * @return void 
    */
    private void filterList(List<SObject> listToFilter, List<SObject> newList, List<SObject> filteredList) {
        if(listToFilter != null && listToFilter.size() > 0) {
            for(integer i=0; i<listToFilter.size();i++) {
                if (newList != null && newList.size() > 0) {
                    if(newList[i].get(fieldName) != filterValue) {
                        filteredList.add(listToFilter[i]);
                    }
                } else {
                    if(listToFilter[i].get(fieldName) != filterValue) {
                        filteredList.add(listToFilter[i]);
                    }
                }
            }
        } 
    }
    
    /*******************************************************************************************************
    * @description Wrapper containing the filtered new and old lists of records, so we can return both simultaneously 
    * from a method.
    */
    public class FilteredLists {
        public List<SObject> newList;
        public List<SObject> oldList;
        
        public FilteredLists() {
            newList = new List<SObject>();
            oldList = new List<SObject>();
        }
    }
    
    /*******************************************************************************************************
    * @description Wrapper representing a link in the chain obtained from the filtering condition.
    */
    public class ChainLink {
        public SObjectField field;
        public String fieldName;
        public String objectReferenced;
        public String parentName;
        public Integer objectChainIndex;
        
        public ChainLink(SObjectField field, String objectReferenced, String parentName, Integer objectChainIndex) {
            this.field = field;
            this.fieldName = this.field.getDescribe().getName(); //@TODO: optimize this to save describe calls?
            this.objectReferenced = objectReferenced;
            this.parentName = parentName;
            this.objectChainIndex = objectChainIndex;
        }
    }
}