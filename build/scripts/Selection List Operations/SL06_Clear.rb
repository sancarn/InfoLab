class WSLocalStorage < Hash
	def WSLocalStorage.new(identifier)
		$local ||= {}
		$local[identifier] ||= {}
		return $local[identifier]
	end
end

localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
if localStorage[:id]
  net = WSApplication.current_network
  net.clear_selection
  net.save_selection localStorage[:id]
else
  WSApplication.message_box("No selection list selected","OK","!",nil)
end
