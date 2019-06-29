class WSLocalStorage < Hash
	def WSLocalStorage.new(identifier)
		$local ||= {}
		$local[identifier] ||= {}
		return $local[identifier]
	end
end

localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")    # 'Selection List' operations GUID: a8344089-9f06-4058-9955-57283c090659
localStorage[:id] = nil


selectionLists = {}
sls = WSApplication.current_database.model_object_collection('Selection list')
if sls.count > 0
  sls.each do |mo|
    selectionLists[mo.name] = mo.id
  end
  data = WSApplication.prompt("Select selection list",[["Choose a selection list...","String",selectionLists.keys[0],nil,"LIST",selectionLists.keys]],false)
  if data
    #Get ID
    id = selectionLists[data[0]]
    
    # If selection list is selected, setup selection list
    # Get the user to select the selection list ID they wish to operate on:
    localStorage[:id] = id

    # Check that model object is of type selection list, and error if not:
    iwdb = WSApplication.current_database
    begin
      iwdb.model_object_from_type_and_id("Selection list",localStorage[:id])
    rescue RuntimeError
      localStorage[:id] = nil
      WSApplication.message_box("ID selected is not the ID of a selection list.","OK","!",nil)
    end
  end
else
  WSApplication.message_box("No selection lists in the database","OK","!",nil)
end




