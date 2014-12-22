#!/usr/bin/ruby

require 'rubygems'
require 'sqlite3'
require 'fileutils'

dbname = "c:/Program Files (x86)/Archimista/application/archimista.db" #nome del db da interrogare, defualt c:/Program Files (x86)/Archimista/application/archimista.db NB FARE UN BACKUP DEL DATABASE PRIMA DI AVVIARE LO SCRIPT
fond_id = "" #id del fondo su cui si vuole operare
$img_dir_pub = "c:/Program Files (x86)/Archimista/application/public/digital_objects/" # default la cartella digital_objects su windows a 64bit, su un windows a 32 bit sara' qualcosa come c:/Program Files/Archimista/application/public/digital_objects/
$dest = "" # Directory in cui copiare le immagini esempio E:/downloads/copy_img

basedir = Dir.getwd  
$logfile = basedir + "/log.txt"



def copy_dobj(list)
	if $dest == "" 
		puts "Manca la direcotry di destinazione"
	else
		if !(File.directory? $dest) 
			Dir.mkdir($dest, 0755)
		end
		list.each do |dir|
			FileUtils.cp_r(File.join($img_dir_pub, dir), $dest)
		end
	end
end

def print_dobj(list)
	open($logfile, 'w') { |f|
		f << "Lista delle cartelle contenenti oggetti digitali associati al fondo prescelto\n"
	}
	list.each do |dir|
		open($logfile, 'a') { |f|
		f << dir + "\n"
		}
	end
end

begin
	# controllo che tutte le variabili siano dichiarate
	if dbname == "" || fond_id == ""
		puts "Manca qualche variabile o hai inserito valori non accettati"
	else
		db = SQLite3::Database.new dbname
		db.results_as_hash = true
		list = Array.new
		#Seleziona tutte le immagini collegate a un unita'
		stm = db.prepare "Select * FROM digital_objects, units WHERE digital_objects.attachable_id = units.id AND digital_objects.attachable_type='Unit' AND units.root_fond_id = :fond_id"
		rs = stm.execute fond_id
		rs.each do |row|
			list.push(row["access_token"])
		end
		stm.close if stm
		#Seleziona tutte le immagini collegate a un fondo
		root_fond = fond_id + "/%"
		stm = db.prepare "Select * FROM digital_objects, fonds WHERE digital_objects.attachable_id = fonds.id AND digital_objects.attachable_type='Fond' AND (fonds.ancestry = :fond_id OR fonds.ancestry LIKE :root_fond OR fonds.id=:fond_id)"
		rs = stm.execute fond_id, root_fond 
		rs.each do |row|
			list.push(row["access_token"])
		end
		stm.close if stm
		
		copy_dobj(list)
		print_dobj(list)
	end			
	rescue SQLite3::Exception => e 
			
		puts "Exception occurred"
		puts e

	ensure
		db.close if db
end		
