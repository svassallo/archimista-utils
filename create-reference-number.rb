#!/usr/bin/ruby

require 'rubygems'
require 'sqlite3'

dbname = "c:/Program Files (x86)/Archimista/application/archimista.db" #nome del db da interrogare, defualt c:/Program Files (x86)/Archimista/application/archimista.db NB FARE UN BACKUP DEL DATABASE PRIMA DI AVVIARE LO SCRIPT
fond_id = "" #id del fondo su cui si vuole operare
folder_prefix ="b." #prefisso usato prima della busta
file_prefix ="fasc." #prefisso usato prima del fascicolo


begin
	# controllo che tutte le variabili siano dichiarate
	if dbname == "" || fond_id == ""
		puts "Manca qualche variabile o hai inserito valori non accettati"
	else
		# ciclo, prende in esame tutte le cartelle all'interno di img_dir
		db = SQLite3::Database.new dbname
		db.results_as_hash = true
		stm = db.prepare "SELECT * FROM units WHERE folder_number != '' AND file_number != '' AND root_fond_id = :fond_id"
		rs = stm.execute fond_id
		rs.each do |row|
			reference_number = folder_prefix + " " + row["folder_number"].to_s + " " + file_prefix + " " + row["file_number"].to_s
			db.execute "UPDATE units SET reference_number = ? WHERE id = ?", reference_number, row["id"]
		end
		stm.close if stm
	end			
	rescue SQLite3::Exception => e 
			
		puts "Exception occurred"
		puts e

	ensure
		db.close if db		
end
