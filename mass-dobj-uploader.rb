#!/usr/bin/ruby

require 'rubygems'
require 'sqlite3'
require 'digest/sha1'
require 'fileutils'
require 'open3'

dbname = "c:/Program Files (x86)/Archimista/application/archimista.db" #nome del db da interrogare, defualt c:/Program Files (x86)/Archimista/application/archimista.db NB FARE UN BACKUP DEL DATABASE PRIMA DI AVVIARE LO SCRIPT
fond_id = "" #id del fondo su cui si vuole operare
img_dir = "" # cartella che contiene tutte le cartelle che si vogliono processare automaticamente
img_dir_pub = "c:/Program Files (x86)/Archimista/application/public/digital_objects/" # default la cartella digital_objects su windows a 64bit, su un windows a 32 bit sara' qualcosa come c:/Program Files/Archimista/application/public/digital_objects/
user_id = "" # utente usato per creare il fondo
group_id = "" # gruppo a cui appartiene l'utente

basedir = Dir.getwd  
logfile = basedir + "/log.txt"

open(logfile, 'w') { |f|
  f << "File di log del caricamento massivo di immagini. Impostazioni usate:\n"
  f << "database: " + dbname + "\n"
  f << "id del fondo: "+ fond_id + "\n"
  f << "cartella contenitore contenente le cartelle da analizzare: " + img_dir + "\n"
  f << "cartella di Archimista dove caricare le immagini: " + img_dir_pub + "\n"
  f << "Id utente di Archimista: " + user_id + "\n"
  f << "Id del gruppo di Archimista: " + group_id + "\n"
  f << "\n"
}
begin
	# controllo che tutte le variabili siano dichiarate
	if dbname == "" || fond_id == "" || img_dir == "" || user_id == "" || group_id == ""
		puts "Manca qualche variabile o hai inserito valori non accettati"
		open(logfile, 'a') { |f|
			f << "Manca qualche variabile o hai inserito valori non accettati"
		}
	else
		# ciclo, prende in esame tutte le cartelle all'interno di img_dir
		db = SQLite3::Database.new dbname
		db.results_as_hash = true
		Dir.chdir(img_dir)
		Dir.foreach(".") do |item|
			# per ogni cartella cerca una corrispondenza univoca nel db
			next if item == '.' or item == '..' or !(File.directory? item)
			open(logfile, 'a') { |f|
				f << "Analizzo cartella " + item + " cercando una corispondenza nel db\n"
			}			
			# cambiare qui se la digitalizzazione e fatta a livello di complessi (fonds al posto di units) e il campo per cui si effettua il testo in questo caso file_number, potrebbe essere reference_number etc
			stm = db.prepare "SELECT count(*) as count FROM units WHERE root_fond_id = :fond_id AND file_number = :item"
			count = stm.execute fond_id, item
			counter = count.next["count"]	
			stm.close if stm			
			if counter == 1
				# se viene trovata una corrispondenza univoca entra nella cartella e processa tutti i file jpeg
				open(logfile, 'a') { |f|
					f << "Corrispondenza univoca trovata\n"
				}	
				# cambiare qui se la digitalizzazione e fatta a livello di complessi (fonds al posto di units) e il campo per cui si effettua il testo in questo caso file_number, potrebbe essere reference_number etc
				stm = db.prepare "SELECT id FROM units WHERE root_fond_id = :fond_id AND file_number = :item"
				rs = stm.execute fond_id, item
				attach_id = rs.next["id"]
				stm.close if stm
				position = 0
				Dir.chdir(item)
				Dir.glob("*.{jpg}").each do |img|
					position = position + 1
					open(logfile, 'a') { |f|
						f << "Processo il file " + img + "\n"
					}						
					# come titolo si usa il nome file senza estensione, possibile cambiare qui, es usando numeri crescenti
					title = File.basename(img, ".*" )
					size = File.size(img)
					access_token = Digest::SHA1.hexdigest("#{img}#{Time.now.to_i}")
					new_dir = img_dir_pub + access_token
					Dir.mkdir(new_dir, 0755)
					# copia il file originale nel cartella public (img_dir_pub) di Archimista, qui al posto della copia 1:1 si puo' inserire un convert se da tiff si vuole caricare direttamente una derivata
					FileUtils.cp(img, File.join(new_dir, "original.jpg"))
					
					# gruppo di comandi per creare derivate, da migliorare medium e thumb possono essere generate da large invece che dall'immagine originale
					`convert "#{img}" -resize 1280x1280 "#{new_dir}"/large.jpg` 
					`convert "#{img}" -resize 210x210 "#{new_dir}"/medium.jpg` 
					`convert "#{img}" -resize 130x130 "#{new_dir}"/thumb.jpg`
					
					updated_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
					# inserimento oggetto digitale nel db, cambiare qui Unit se invece che per unita' l'inserimento a catena viene fatto su fond
					db.execute "INSERT INTO digital_objects(attachable_type, attachable_id, position, title, access_token, asset_file_name, asset_content_type, asset_file_size, asset_updated_at, created_by, updated_by, group_id, created_at, updated_at) VALUES ('Unit', ?, ?, ?, ?, ?, 'image/jpeg', ?, ?, ?, ?, ?, ?, ?)", attach_id, position, title, access_token, img, size, updated_time, user_id, user_id, group_id, updated_time,  updated_time
					
				end
				Dir.chdir("..")
			elsif counter == 0
				open(logfile, 'a') { |f|
					f << "nessuna corrispondenza trovata per " + item + "\n"
				}		
			else
				open(logfile, 'a') { |f|
					f << "corrispondenza per #{item} non univoca, trovate #{counter} corrispondenze\n"
				}						
			end
			open(logfile, 'a') { |f|
				f << "\n"
			}			
		end
	end			
	rescue SQLite3::Exception => e 
			
		puts "Exception occurred"
		puts e

	ensure
		db.close if db		
end
