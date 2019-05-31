class WSLocalStorage < Hash
	def WSLocalStorage.new(identifier)
		$local ||= {}
		$local[identifier] ||= {}
		return $local[identifier]
	end
end

localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")    # 'Selection List' operations GUID: a8344089-9f06-4058-9955-57283c090659
localStorage[:id] = nil

sls=WSApplication.current_database.model_object_collection('Selection list')
if sls.count > 0
  sl = sls.enum_for(:each).max_by {|sl| sl.id} #Max Selection list ID
  localStorage[:id] = sl.id
else 
  WSApplication.message_box("No selection lists in the database","OK","!",nil)
end