﻿--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
---- FONCTIONS LOCALES ET GLOBALES POUR LE PARTAGE DE DONNÉES AU SEIN DU RESEAU DES CBN ----
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

--- Création de la table de log
CREATE TABLE IF NOT EXISTS "public"."zz_log" ("libSchema" character varying,"libTable" character varying,"libChamp" character varying,"typLog" character varying,"libLog" character varying,"nbOccurence" character varying,"date" date);

---------------------------------------------------------------------------------------------------------
--- Suppression des données de la partie propre (à partir de celles présentes dans la partie temporaire)
---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION hub_checkout (libSchema varchar, jdd varchar = 'all') RETURNS setof zz_log  AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE typJdd varchar; BEGIN
--- Variables
CASE WHEN jdd = 'data' OR jdd = 'taxa' THEN
	typJdd := Jdd;
	---
ELSE EXECUTE 'SELECT "typJdd" FROM "'||libSchema||'"."temp_metadonnees" WHERE "cdJdd" = '''||typJdd||'''' INTO typJdd;
	---
	---
END CASE;
---Commandes
---EXECUTE '
---DELETE FROM "'||leschema||'".metadonnees WHERE "cdJdd" IN (SELECT "cdJdd" FROM "'||leschema||'".temp_metadonnees);
---DELETE FROM "'||leschema||'".observation WHERE "cdObsPermanent" IN (SELECT "cdObsPermanent" FROM "'||leschema||'".temp_observation);
---DELETE FROM "'||leschema||'".observation_territoire WHERE "cdObsPermanent" IN (SELECT "cdObsPermanent" FROM "'||leschema||'".temp_observation_territoire);
---DELETE FROM "'||leschema||'".observation_acteurs WHERE "cdObsPermanent" IN (SELECT "cdObsPermanent" FROM "'||leschema||'".temp_observation_acteurs);
---';
--- Output&Log
out."libSchema" := libSchema; out."libChamp" := '-'; out."typLog" := 'hub_checkout';out."libLog" := 'Fonction non implémentée';SELECT CURRENT_TIMESTAMP INTO out."date";
RETURN next out;END;$BODY$ LANGUAGE plpgsql;


------------------------------------------
--- Nettoyage des tables temporaires
------------------------------------------
CREATE OR REPLACE FUNCTION hub_clear(libSchema varchar, jdd varchar, typBdd varchar = 'temp') RETURNS setof zz_log  AS 
$BODY$  DECLARE out zz_log%rowtype; DECLARE libTable varchar;DECLARE prefixe varchar; DECLARE typJdd varchar; DECLARE cdJdd varchar; DECLARE wheres varchar; DECLARE flag integer; DECLARE presence_jdd integer;
BEGIN
--- Variables
CASE WHEN typBdd = 'temp' 	THEN 	flag :=1; prefixe = 'temp_';
	WHEN typBdd = 'propre' 	THEN 	flag :=1; prefixe = '';
	ELSE  				flag :=0;
END CASE;
CASE WHEN flag = 1 THEN
	EXECUTE 'SELECT 1 FROM "'||libSchema||'"."'||prefixe||'metadonnees" WHERE "cdJdd" = '''||jdd||'''' INTO presence_jdd;
	CASE WHEN jdd = 'data' OR jdd = 'taxa' THEN 
		flag :=2; 
		typJdd := jdd; 
		wheres := 'WHERE 1=1';
		FOR cdJdd IN EXECUTE 'SELECT cdJdd FROM "'||libSchema||'"."'||prefixe||'metadonnees" WHERE typJdd = '''||jdd||''''
			LOOP wheres := wheres||' "cdJdd" = '''||cdJdd||'''';END LOOP;
	WHEN presence_jdd = 1 THEN
		flag :=2;
		EXECUTE 'SELECT typJdd FROM "'||libSchema||'"."'||prefixe||'metadonnees" WHERE cdJdd = '''||jdd||'''' INTO typJdd;
		wheres := 'WHERE "cdJdd" = '''||jdd||'''';
	ELSE out."libLog" = 'ALERT : Mauvais jdd';
	END CASE;
ELSE out."libLog" = 'ALERT : Mauvais typBdd';
END CASE;

--- Commandes
CASE WHEN flag = 2 THEN
	FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd
		LOOP EXECUTE 'DELETE FROM "'||libSchema||'"."'||prefixe||libTable||'" '||wheres||';'; END LOOP;
	FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_meta'
		LOOP EXECUTE 'DELETE FROM "'||libSchema||'"."'||prefixe||libTable||'" '||wheres||';'; END LOOP;
	out."libLog" = jdd||' effacé des tables temporaires';
ELSE EXECUTE 'SELECT 1;';
END CASE;

--- Output&Log
out."libSchema" := libSchema;out."libTable" := '-';out."libChamp" := '-';out."typLog" := 'hub_clear';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
RETURN next out; END; $BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Créer un hub
------------------------------------------
CREATE OR REPLACE FUNCTION hub_clone(libSchema varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE flag integer; BEGIN
--- Variable
EXECUTE 'SELECT DISTINCT 1 FROM pg_tables WHERE schemaname = '''||libSchema||''';' INTO flag;
--- Commande
CASE WHEN flag = 1 THEN
	out."libLog" := 'Schema '||libSchema||' existe déjà';
ELSE EXECUTE '
	CREATE SCHEMA "'||libSchema||'";

	--- META : PARTIE PROPRE 
	CREATE TABLE "'||libSchema||'".metadonnees 		("cdJddPerm" character varying, "cdJdd" character varying NOT NULL,"typJdd" character varying NOT NULL,"libJdd" character varying NOT NULL,"descJdd" character varying,"rmq" character varying, 
									CONSTRAINT metadonnees_pkey PRIMARY KEY ("cdJddPerm"));
	CREATE TABLE "'||libSchema||'".metadonnees_territoire 	("cdJddPerm" character varying,"cdJdd" character varying NOT NULL,"cdGeo" character varying,"typGeo" character varying,"cdRefGeo" character varying NOT NULL,"versionRefGeo" character varying NOT NULL,"rmq" character varying, 
									CONSTRAINT metadonnees_territoire_pkey PRIMARY KEY ("cdJddPerm","typGeo","cdGeo"),CONSTRAINT metadonnees_territoire_fk FOREIGN KEY ("cdJddPerm") REFERENCES "'||libSchema||'".metadonnees ("cdJddPerm"));
	CREATE TABLE "'||libSchema||'".metadonnees_acteur 	("cdJddPerm" character varying,"cdJdd" character varying NOT NULL,"typActeur" character varying,"nomActeur" character varying,"libOrgm" character varying,"mailActeur" character varying,"cdActeur" character varying,"cdOrgm" character varying,	"rmq" character varying,
									CONSTRAINT metadonnees_acteur_pkey PRIMARY KEY ("cdJddPerm","typActeur","nomActeur","libOrgm"),CONSTRAINT metadonnees_acteur_fk FOREIGN KEY ("cdJddPerm") REFERENCES "'||libSchema||'".metadonnees ("cdJddPerm"));
	CREATE TABLE "'||libSchema||'".metadonnees_date 		("cdJddPerm" character varying,"cdJdd" character varying NOT NULL,"typAction" character varying,"dateDebut" character varying,"dateFin" character varying,"natureDate" character varying NOT NULL,"rmq" character varying,
									CONSTRAINT metadonnees_date_pkey PRIMARY KEY ("cdJddPerm","typAction","dateDebut","dateFin"),CONSTRAINT metadonnees_date_fk FOREIGN KEY ("cdJddPerm") REFERENCES "'||libSchema||'".metadonnees ("cdJddPerm"));
	--- META : PARTIE TEMPORAIRE
	CREATE TABLE "'||libSchema||'".temp_metadonnees 			("cdJddPerm" character varying,"cdJdd" character varying,"typJdd" character varying,"libJdd" character varying,"descJdd" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_metadonnees_territoire 	("cdJddPerm" character varying,"cdJdd" character varying,"cdGeo" character varying,"typGeo" character varying,"cdRefGeo" character varying,"versionRefGeo" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_metadonnees_acteur 		("cdJddPerm" character varying,"cdJdd" character varying,"typActeur" character varying,"nomActeur" character varying,"libOrgm" character varying,"mailActeur" character varying,"cdActeur" character varying,"cdOrgm" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_metadonnees_date 		("cdJddPerm" character varying,"cdJdd" character varying,"typAction" character varying,"dateDebut" character varying,"dateFin" character varying,"natureDate" character varying,"rmq" character varying);

	--- DATA : PARTIE PROPRE
	CREATE TABLE "'||libSchema||'".releve 			("cdJdd" character varying  NOT NULL,"cdReleve" character varying NOT NULL,"cdRelevePerm" character varying,"typReleve" character varying NOT NULL,"cdDisp" character varying,"typDisp" character varying NOT NULL,"libDisp" character varying,"descDisp" character varying,"cdHab" character varying,"cdRefHab" character varying,"versionRefHab" character varying,"cdIDCNP" character varying,"rmq" character varying,
									CONSTRAINT releve_pkey PRIMARY KEY ("cdRelevePerm"));
	CREATE TABLE "'||libSchema||'".observation 		("cdJddPerm" character varying NOT NULL,"cdJdd" character varying NOT NULL,"cdRelevePerm" character varying,"cdObsPerm" character varying,"typEnt" character varying NOT NULL,"cdObsMere" character varying NOT NULL,"cdEntMere" character varying,"nomEntMere" character varying,"cdRef" character varying NOT NULL,"cdNom" character varying,"cdRefTaxo" character varying NOT NULL,"versionRefTaxo" character varying NOT NULL,"nomEntRef" character varying NOT NULL,"cdObsOrig" character varying,"cdEntOrig" character varying,"nomEntOrig" character varying,"cdJddOrig" character varying,"libJddOrig" character varying,"typSource" character varying NOT NULL,"cdBiblio" character varying,"libBiblio" character varying,"urlBiblio" character varying,"cdHerbier" character varying,"libHerbier" character varying,"cdValidite" integer NOT NULL,"cdSensi" integer NOT NULL,"libRefSensi" character varying,"versionRefSensi" character varying,"proprieteObs" character varying NOT NULL,"statutPop" integer NOT NULL,"typDenombt" character varying,"denombtMin" integer,"denombtMax" integer,"objetDenombt" character varying,"rmq" character varying,
									CONSTRAINT observation_pkey PRIMARY KEY ("cdObsPerm"),CONSTRAINT observation_fk FOREIGN KEY ("cdJddPerm") REFERENCES "'||libSchema ||'".metadonnees ("cdJddPerm"),CONSTRAINT observation_releve_fk FOREIGN KEY ("cdRelevePerm") REFERENCES "'||libSchema||'".releve ("cdRelevePerm"));
	CREATE TABLE "'||libSchema||'".observation_territoire 	("cdJdd" character varying NOT NULL,"cdObsPerm" character varying,"cdObsMere" character varying NOT NULL,"typGeo" character varying,"cdRefGeo" character varying NOT NULL,"versionRefGeo" character varying NOT NULL,"cdGeo" character varying,"libGeo" character varying,"confianceGeo" character varying NOT NULL,"moyenGeo" character varying NOT NULL,"natureGeo" character varying NOT NULL,"origineGeo" character varying NOT NULL,"precisionGeo" float,"rmq" character varying,
									CONSTRAINT observation_territoire_pkey PRIMARY KEY ("cdObsPerm","typGeo","cdGeo"),CONSTRAINT observation_territoire_fk FOREIGN KEY ("cdObsPerm") REFERENCES "'||libSchema ||'".observation ("cdObsPerm"));
	CREATE TABLE "'||libSchema||'".observation_acteur 	("cdJdd" character varying NOT NULL,"cdObsPerm" character varying,"cdObsMere" character varying NOT NULL,"typActeur" character varying,"nomActeur" character varying,"libOrgm" character varying NOT NULL,"mailActeur" character varying,"cdActeur" character varying,"cdOrgm" character varying, "rmq" character varying,
									CONSTRAINT observation_acteur_pkey PRIMARY KEY ("cdObsPerm","typActeur","nomActeur","libOrgm"),CONSTRAINT observation_territoire_fk FOREIGN KEY ("cdObsPerm") REFERENCES "'||libSchema ||'".observation ("cdObsPerm"));
	CREATE TABLE "'||libSchema||'".observation_date 		("cdJdd" character varying NOT NULL,"cdObsPerm" character varying,"cdObsMere" character varying NOT NULL,"typAction" character varying,"dateDebut" character varying,"dateFin" character varying,"natureDate" character varying NOT NULL,"rmq" character varying,
									CONSTRAINT observation_date_pkey PRIMARY KEY ("cdObsPerm","typAction","dateDebut","dateFin"),CONSTRAINT observation_territoire_fk FOREIGN KEY ("cdObsPerm") REFERENCES "'||libSchema ||'".observation ("cdObsPerm"));
	--- DATA : PARTIE TEMPORAIRE
	CREATE TABLE "'||libSchema||'".temp_releve			("cdJdd" character varying,"cdReleve" character varying,"cdRelevePerm" character varying,"typReleve" character varying,"cdDisp" character varying,"typDisp" character varying,"libDisp" character varying,"descDisp" character varying,"cdHab" character varying,"cdRefHab" character varying,"versionRefHab" character varying,"cdIDCNP" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_observation 			("cdJddPerm" character varying,"cdJdd" character varying,"cdRelevePerm" character varying,"cdObsPerm" character varying,"typEnt" character varying,"cdObsMere" character varying,"cdEntMere" character varying,"nomEntMere" character varying,"cdRef" character varying,"cdNom" character varying,"cdRefTaxo" character varying,"versionRefTaxo" character varying,"nomEntRef" character varying,"cdObsOrig" character varying,"cdEntOrig" character varying,"nomEntOrig" character varying,"cdJddOrig" character varying,"libJddOrig" character varying,"typSource" character varying,"cdBiblio" character varying,"libBiblio" character varying,"urlBiblio" character varying,"cdHerbier" character varying,"libHerbier" character varying,"cdValidite" character varying,"cdSensi" character varying,"libRefSensi" character varying,"versionRefSensi" character varying,"proprieteObs" character varying,"statutPop" character varying,"typDenombt" character varying,"denombtMin" character varying,"denombtMax" character varying,"objetDenombt" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_observation_territoire 	("cdJdd" character varying,"cdObsPerm" character varying,"cdObsMere" character varying,"typGeo" character varying,"cdRefGeo" character varying,"versionRefGeo" character varying,"cdGeo" character varying,"libGeo" character varying,"confianceGeo" character varying,"moyenGeo" character varying,"natureGeo" character varying,"origineGeo" character varying,"precisionGeo" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_observation_acteur 		("cdJdd" character varying,"cdObsPerm" character varying,"cdObsMere" character varying,"typActeur" character varying,"nomActeur" character varying,"libOrgm" character varying,"mailActeur" character varying,"cdActeur" character varying,"cdOrgm" character varying,	"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_observation_date 		("cdJdd" character varying,"cdObsPerm" character varying,"cdObsMere" character varying,"typAction" character varying,"dateDebut" character varying,"dateFin" character varying,"natureDate" character varying,"rmq" character varying);

	--- TAXA : PARTIE PROPRE
	CREATE TABLE "'||libSchema||'".entite 			("cdJddPerm" character varying NOT NULL,"cdJdd" character varying NOT NULL,"typEnt" character varying NOT NULL,"cdEntMere" character varying NOT NULL,"cdEntPerm" character varying,"nomEntMere" character varying NOT NULL,"cdSup" character varying,"cdRang" character varying,"famille" character varying,"ordre" character varying,"classe" character varying,"phylum" character varying,"regne" character varying,"rmq" character varying,
									CONSTRAINT entite_pkey PRIMARY KEY ("cdEntPerm"),CONSTRAINT entite_fk FOREIGN KEY ("cdJddPerm") REFERENCES "'||libSchema||'".metadonnees ("cdJddPerm"));
	CREATE TABLE "'||libSchema||'".entite_statut 		("cdJdd" character varying NOT NULL,"cdEntPerm" character varying,"cdEntMere" character varying NOT NULL,"typStatut" character varying,"cdStatut" character varying,"critereStatut" character varying,"methodeStatut" character varying,"anneeStatut" date,"valeurStatut" float,"metriqueStatut" character varying,"typGeo" character varying,"cdGeo" character varying,"cdRefGeo" character varying NOT NULL,"versionRefGeo" character varying NOT NULL,"libGeo" character varying,"rmq" character varying,
									CONSTRAINT entite_statut_pkey PRIMARY KEY ("cdEntPerm","typStatut","typGeo","cdGeo"),CONSTRAINT entite_statut_fk FOREIGN KEY ("cdEntPerm") REFERENCES "'||libSchema||'".entite ("cdEntPerm"));
	CREATE TABLE "'||libSchema||'".entite_referentiel 	("cdJdd" character varying NOT NULL,"cdEntPerm" character varying,"cdEntMere" character varying NOT NULL,"cdNom" character varying,"cdRef" character varying NOT NULL,"nomEntRef" character varying NOT NULL,"cdRefTaxo" character varying,"versionRefTaxo" character varying,"rmq" character varying,
									CONSTRAINT entite_referentiel_pkey PRIMARY KEY ("cdEntPerm","cdRefTaxo","versionRefTaxo"),CONSTRAINT entite_referentiel_fk FOREIGN KEY ("cdEntPerm") REFERENCES "'||libSchema||'".entite ("cdEntPerm"));
	CREATE TABLE "'||libSchema||'".entite_verna 		("cdJdd" character varying NOT NULL,"cdEntPerm" character varying,"cdEntMere" character varying NOT NULL,"nomEntVerna" character varying,"rmq" character varying,
									CONSTRAINT entite_verna_pkey PRIMARY KEY ("cdEntPerm","nomEntVerna"),CONSTRAINT entite_verna_fk FOREIGN KEY ("cdEntPerm") REFERENCES "'||libSchema||'".entite ("cdEntPerm"));
	CREATE TABLE "'||libSchema||'".entite_biblio 		("cdJdd" character varying NOT NULL,"cdEntPerm" character varying,"cdEntMere" character varying NOT NULL,"typBiblio" character varying,"cdBiblio" character varying,"libBiblio" character varying,"urlBiblio" character varying,"rmq" character varying,
									CONSTRAINT entite_biblio_pkey PRIMARY KEY ("cdEntPerm","typBiblio","cdBiblio"),CONSTRAINT entite_biblio_fk FOREIGN KEY ("cdEntPerm") REFERENCES "'||libSchema||'".entite ("cdEntPerm"));
	--- TAXA : PARTIE TEMPORAIRE
	CREATE TABLE "'||libSchema||'".temp_entite 			("cdJddPerm" character varying, "cdJdd" character varying,"typEnt" character varying,"cdEntMere" character varying,"cdEntPerm" character varying, "nomEntMere" character varying,"cdSup" character varying,"cdRang" character varying,"famille" character varying,"ordre" character varying,"classe" character varying,"phylum" character varying,"regne" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_entite_statut 		("cdJdd" character varying,"cdEntPerm" character varying,"cdEntMere" character varying,"typStatut" character varying,"cdStatut" character varying,"critereStatut" character varying,"methodeStatut" character varying,"anneeStatut" character varying,"valeurStatut" character varying,"metriqueStatut" character varying,"typGeo" character varying,"cdGeo" character varying,"cdRefGeo" character varying,"versionRefGeo" character varying,"libGeo" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_entite_referentiel 		("cdJdd" character varying,"cdEntPerm" character varying,"cdEntMere" character varying,"cdNom" character varying,"cdRef" character varying,"nomEntRef" character varying,"cdRefTaxo" character varying,"versionRefTaxo" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_entite_verna 		("cdJdd" character varying,"cdEntPerm" character varying,"cdEntMere" character varying,"nomEntVerna" character varying,"rmq" character varying);
	CREATE TABLE "'||libSchema||'".temp_entite_biblio 		("cdJdd" character varying,"cdEntPerm" character varying,"cdEntMere" character varying,"typBiblio" character varying,"cdBiblio" character varying,"libBiblio" character varying,"urlBiblio" character varying,"rmq" character varying);

	--- LISTE TAXON
	CREATE TABLE "'||libSchema||'".zz_log_liste_taxon  ("cdRef" character varying,"nomValide" character varying);
	CREATE TABLE "'||libSchema||'".zz_log_liste_taxon_et_infra  ("cdRefDemande" character varying,"nomValideDemande" character varying, "cdRefCite" character varying, "nomCompletCite" character varying, "rangCite" character varying, "cdTaxsupCite" character varying);

	--- LOG
	CREATE TABLE "'||libSchema||'".zz_log  ("libSchema" character varying,"libTable" character varying,"libChamp" character varying,"typLog" character varying,"libLog" character varying,"nbOccurence" character varying,"date" date);
	';
	out."libLog" := 'Schema '||libSchema||' créé';
END CASE;
--- Output&Log
out."libSchema" := libSchema;out."libTable" := '-';out."libChamp" := '-';out."typLog" := 'hub_clone';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
RETURN next out; END; $BODY$ LANGUAGE plpgsql;


------------------------------------------
--- Analyse des différences entre la partie temporaire et la partie propre
------------------------------------------
--- Attention, ne gère pas les relevés
--- Fonction à finaliser par rapport aux cdJdd (vs data et taxa)
CREATE OR REPLACE FUNCTION hub_diff(libSchema varchar, jdd varchar) RETURNS setof zz_log  AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE flag integer;DECLARE presence_jdd varchar;DECLARE wheres varchar; DECLARE cdJdd varchar;DECLARE typJdd varchar;DECLARE whereJdd varchar; DECLARE compte integer; DECLARE tableListe varchar array; 
DECLARE libChamp varchar; DECLARE libTable varchar;  DECLARE champRef varchar;  DECLARE tableRef varchar; BEGIN
--- Variables Jdd
EXECUTE 'SELECT 1 FROM "'||libSchema||'"."temp_metadonnees" WHERE "cdJdd" = '''||jdd||'''' INTO presence_jdd;
CASE WHEN jdd = 'data' OR jdd = 'taxa' THEN 
	flag :=1; 
	typJdd := jdd; 
	whereJdd := 'WHERE 1=1';
	FOR cdJdd IN EXECUTE 'SELECT "cdJdd" FROM "'||libSchema||'".temp_metadonnees WHERE typJdd = '''||jdd||''''
		LOOP wheres := wheres||' "cdJdd" = '''||cdJdd||'''';END LOOP;
WHEN presence_jdd = 1 THEN
	flag :=1;
	EXECUTE 'SELECT "typJdd" FROM "'||libSchema||'".temp_metadonnees WHERE cdJdd = '''||jdd||'''' INTO typJdd;
	whereJdd := 'WHERE "cdJdd" = '''||jdd||'''';
ELSE flag :=0; out."libLog" = 'ALERT : Mauvais jdd';
END CASE;
--- Variables Ref
CASE 	WHEN typJdd = 'data' THEN 	champRef = 'cdObsPerm';	tableRef = 'observation'; 
	WHEN typJdd = 'taxa' THEN 	champRef = 'cdEntPerm';	tableRef = 'entite'; 
	ELSE 				champRef = ''; 		tableRef = '';END CASE;
--- Output
out."libSchema" := libSchema; out."libChamp" := '-'; out."typLog" := 'hub_diff';SELECT CURRENT_TIMESTAMP INTO out."date";
--- Commandes
--- Ajout meta
compte := 0;
EXECUTE 'SELECT count(z."cdJddPerm") FROM "'||libSchema||'"."temp_metadonnees" z LEFT JOIN "'||libSchema||'"."metadonnees" a ON z."cdJddPerm" = a."cdJddPerm" WHERE a."cdJddPerm" IS NULL' INTO compte; 
CASE WHEN (compte > 0) THEN
	out."libTable" := 'metadonnees'; out."libLog" := 'Nouveaux jeu de données'; out."nbOccurence" := compte||' occurence(s)'; return next out;--- Log
	EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
ELSE EXECUTE 'SELECT 1';
END CASE;	

--- Ajout data ou taxa
compte := 0;
EXECUTE 'SELECT count(z."'||champRef||'") FROM "'||libSchema||'"."temp_'||tableRef||'" z LEFT JOIN "'||libSchema||'"."'||tableRef||'" a ON z."'||champRef||'" = a."'||champRef||'" WHERE a."'||champRef||'" IS NULL' INTO compte; 
CASE WHEN (compte > 0) THEN
	out."libTable" := tableRef; out."libLog" := 'Nouveaux '||tableRef; out."nbOccurence" := compte||' occurence(s)'; return next out;--- Log
	EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
ELSE EXECUTE 'SELECT 1';
END CASE;	

--- Pour les modifications
compte := 0;
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd||' WHERE tbl_name <> ''releve'' '
	LOOP
	wheres := 'WHERE 1=1';
	FOR libChamp in EXECUTE 'SELECT cd FROM ref.fsd_'||typJdd||' WHERE tbl_name = '''||libTable||''''
		LOOP
		wheres := wheres||' OR a."'||libChamp||'"::varchar <> b."'||libChamp||'"::varchar';
		END LOOP;
	EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" a JOIN "'||libSchema||'"."'||libTable||'" b ON a."'||champRef||'" = b."'||champRef||'" '||wheres||';' INTO compte;
	CASE WHEN (compte > 0) THEN
		out."libTable" := libTable; out."libLog" := 'Modification sur la table '||libTable; out."nbOccurence" := compte||' occurence(s)'; return next out;--- Log
		EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
	ELSE EXECUTE 'SELECT 1';
	END CASE;	
	END LOOP;

-- Suppresion meta
compte := 0;
EXECUTE 'SELECT count(z."cdJddPerm") FROM "'||libSchema||'"."temp_metadonnees" z RIGTH JOIN "'||libSchema||'"."metadonnees" a ON z."cdJddPerm" = a."cdJddPerm" WHERE z."cdJddPerm" IS NULL' INTO compte; 
CASE WHEN (compte > 0) THEN
	out."libTable" := 'temp_metadonnees'; out."libLog" := 'Jeu de données absent de la partie temporaire (à supprimer?)'; out."nbOccurence" := compte||' occurence(s)'; return next out;--- Log
	EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
ELSE EXECUTE 'SELECT 1';
END CASE;	


-- Suppresion data ou taxa
compte := 0;
EXECUTE 'SELECT count(z."'||champRef||'") FROM "'||libSchema||'"."temp_'||tableRef||'" z RIGHT JOIN "'||libSchema||'"."'||tableRef||'" a ON z."'||champRef||'" = a."'||champRef||'" WHERE z."'||champRef||'" IS NULL' INTO compte; 
CASE WHEN (compte > 0) THEN
	out."libTable" := tableRef; out."libLog" := tableRef||' absent de la partie temporaire (à supprimer?)'; out."nbOccurence" := compte||' occurence(s)'; return next out;--- Log
	EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
ELSE EXECUTE 'SELECT 1';
END CASE;	

--- Log général
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''',''-'',''-'',''hub_diff'',''-'',''-'','''||out."date"||''');';
END;$BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Supprimer un hub
------------------------------------------
CREATE OR REPLACE FUNCTION hub_drop(libSchema varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE flag integer; BEGIN
--- Commandes
EXECUTE 'SELECT DISTINCT 1 FROM pg_tables WHERE schemaname = '''||libSchema||''';' INTO flag;
CASE flag WHEN 1 THEN
	EXECUTE 'DROP SCHEMA IF EXISTS "'||libSchema||'" CASCADE;';
	out."libLog" := 'Schema '||libSchema||' supprimé';
ELSE out."libLog" := 'Schema '||libSchema||' inexistant pas dans le Hub';
END CASE;
RETURN next out;
--- Output
out."libSchema" := libSchema;out."libTable" := '-';out."libChamp" := '-';out."typLog" := 'hub_drop';out."nbOccurence" := 1;SELECT CURRENT_TIMESTAMP INTO out."date";
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
END;$BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Exporter les données depuis un hub
------------------------------------------
CREATE OR REPLACE FUNCTION hub_export(libSchema varchar,Jdd varchar,path varchar) RETURNS setof zz_log  AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE libTable varchar; DECLARE typJdd varchar;  DECLARE cdJdd varchar; DECLARE wheres varchar; BEGIN
--- Variables
CASE WHEN Jdd <> 'data' AND Jdd <> 'taxa' THEN 
	EXECUTE 'SELECT typJdd FROM temp_metadonnees WHERE cdJdd = '''||Jdd||'''' INTO typJdd;
	wheres := 'WHERE "cdJdd" = '''||Jdd||'''';
WHEN Jdd = 'data' OR Jdd = 'taxa' THEN 
	typJdd := Jdd;
	wheres := 'WHERE 1=1';
	FOR cdJdd IN EXECUTE 'SELECT cdJdd FROM temp_metadonnees WHERE typJdd = '''||Jdd||''''
		LOOP wheres := wheres||' "cdJdd" = '''||cdJdd||'''';END LOOP;
END CASE;
--- Commandes
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd
	LOOP EXECUTE 'COPY (SELECT * FROM  "'||libSchema||'"."'||libTable||'" '||wheres||') TO '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER '';'' ENCODING ''UTF8'';'; END LOOP;
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_meta'
	LOOP EXECUTE 'COPY (SELECT * FROM  "'||libSchema||'"."'||libTable||'" WHERE "cdJdd" = '||Jdd||') TO '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER '';'' ENCODING ''UTF8'';'; END LOOP;
--- Output&Log
out."libSchema" := libSchema;out."libTable" := '-';out."libChamp" := '-';out."typLog" := 'hub_export';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
out."libLog" :=  Jdd||'exporté';
EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
RETURN next out; END; $BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Extraction de données selon une liste de taxon
------------------------------------------
CREATE OR REPLACE FUNCTION hub_extract (libSchema varchar,Jdd varchar, path varchar) RETURNS setof zz_log  AS 
$BODY$ DECLARE out zz_log%rowtype; BEGIN
---
---
--- Output
out."libSchema" := libSchema; out."libChamp" := '-'; out."typLog" := 'hub_extract';out."libLog" := 'Fonction non implémentée';SELECT CURRENT_TIMESTAMP INTO out."date";
RETURN next out;END;$BODY$ LANGUAGE plpgsql;


------------------------------------------
--- Création de l'aide et Accéder à la description d'un fonction
------------------------------------------
CREATE OR REPLACE FUNCTION hub_help(libFonction varchar = 'all') RETURNS setof varchar AS 
$BODY$ DECLARE out varchar; DECLARE var varchar; DECLARE flag integer; DECLARE testFonction varchar; BEGIN
--- Variable
flag := 0;
FOR testFonction IN EXECUTE 'SELECT id FROM ref.help'
	LOOP 
		 CASE WHEN testFonction = libFonction THEN flag := 1; ELSE EXECUTE 'SELECT 1;'; END CASE; 
	END LOOP;
--- Commande
CASE WHEN libFonction = 'all' THEN
	out := 'Ajouter une des fonctions listée ci-dessous pour avoir sa description : SELECT * FROM hub_help(''fonction'');';RETURN next out;
	FOR testFonction IN EXECUTE 'SELECT id FROM ref.help'
		LOOP out := testFonction;RETURN next out; END LOOP;
WHEN flag = 1 THEN
	out := '-------------------------'; RETURN next out; 
	out := 'Nom de la Fonction = '||libFonction;RETURN next out; 
	EXECUTE 'SELECT ''- Description : ''||"description" FROM ref.help WHERE "id" = '''||libFonction||''';'INTO out;RETURN next out; 
	EXECUTE 'SELECT ''- Type : ''||"type" FROM ref.help WHERE "id" = '''||libFonction||''';' INTO out;RETURN next out; 
	EXECUTE 'SELECT ''- Etat de la fonction : ''||"etat" FROM ref.help WHERE "id" = '''||libFonction||''';'INTO out;RETURN next out;
	EXECUTE 'SELECT ''- Amélioration à prevoir : ''||"amelioration" FROM ref.help WHERE "id" = '''||libFonction||''';'INTO out;RETURN next out;
	out := '-------------------------'; RETURN next out; 
	out := 'Liste des variables :';RETURN next out;
	FOR var IN EXECUTE 'SELECT '' o ''||"id"||'' : ''||"description"||''. Valeurs possibles = ("''||valeurs||''")'' FROM ref.help_var WHERE "'||libFonction||'" = ''oui'';'
		LOOP --- variables d'entrées
		RETURN next var;
		END LOOP;
ELSE out := 'Fonction inexistante';RETURN next out;
END CASE;
END;$BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Production des identifiants uniques
------------------------------------------
CREATE OR REPLACE FUNCTION hub_idPerm(libSchema varchar, nomDomaine varchar, jdd varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE typJdd varchar; DECLARE champMere varchar; DECLARE champRef varchar; DECLARE tableRef varchar; DECLARE listTable varchar; DECLARE listPerm varchar; BEGIN
--- Variables
EXECUTE 'SELECT typJdd FROM temp_metadonnees WHERE cdJdd = '''||jdd||'''' INTO typJdd;
CASE 	WHEN typJdd = 'meta' 	THEN champMere = 'cdJdd'; 	champRef = 'cdJddPerm';	tableRef = 'metadonnees'; 
	WHEN typJdd = 'data' 	THEN champMere = 'cdObsMere';	champRef = 'cdObsPerm';	tableRef = 'observation'; 
	WHEN typJdd = 'taxa' 	THEN champMere = 'cdEntMere';	champRef = 'cdEntPerm';	tableRef = 'entite'; 
				ELSE champMere = ''; 		champRef = ''; 		tableRef = '';END CASE;
--- Output
out."libSchema" := libSchema;out."libTable" := tableRef;out."libChamp" := champRef;out."typLog" := 'hub_idPerm';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
out."libLog" := 'Identifiant permanent produit';
--- Commandes
FOR listPerm IN EXECUTE 'SELECT DISTINCT "'||champMere||'" FROM "'||libSchema||'".temp_'||tableRef||' WHERE "cdJdd" = '''||cdjdd||''')' --- Production de l'idPermanent
	LOOP EXECUTE 'UPDATE "'||libSchema||'"."temp_'||tableRef||'" SET ("'||champRef||'") = ('''||nomdomaine||'/'||champRef||'/''||(SELECT uuid_generate_v4())) WHERE "'||champMere||'" = '''||listPerm||''' AND "cdJdd" = '''||cdJdd||''';';
	out."libTable" := null; RETURN next out;
	END LOOP;	
FOR listTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd||' WHERE tbl_name <> '''||tableRef||''''  --- Peuplement du nouvel idPermanent dans les autres tables
	LOOP EXECUTE 'UPDATE "'||libSchema||'"."temp_'||listTable||'" ot SET "'||champRef||'" = o."'||champRef||'" FROM "'||libSchema||'"."temp_'||tableRef||'" o WHERE o."cdJdd" = ot."cdJdd" AND o."'||champMere||'" = ot."'||champMere||'";';
	out."libTable" := listTable; RETURN next out;
	END LOOP;
--- Log
EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
END; $BODY$ LANGUAGE plpgsql;


------------------------------------------
--- Importer des données (fichiers CSV) dans un hub
------------------------------------------
CREATE OR REPLACE FUNCTION hub_import(libSchema varchar, jdd varchar, path varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE libTable varchar; DECLARE out zz_log%rowtype; DECLARE i varchar; BEGIN
--- Commande
CASE WHEN jdd = 'data' OR jdd = 'taxa' THEN 
	FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||jdd||';'
		LOOP EXECUTE 'COPY "'||libSchema||'".temp_'||libTable||' FROM '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER '';'' ENCODING ''UTF8'';'; END LOOP;
	FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_meta;'
		LOOP EXECUTE 'COPY "'||libSchema||'".temp_'||libTable||' FROM '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER '';'' ENCODING ''UTF8'';'; END LOOP;
	out."libLog" := jdd||' importé depuis '||path;
WHEN jdd = 'listTaxon' THEN 
	EXECUTE 'TRUNCATE TABLE "'||libSchema||'".zz_log_liste_taxon;TRUNCATE TABLE "'||libSchema||'".zz_log_liste_taxon_et_infra;';
	EXECUTE 'COPY "'||libSchema||'".zz_log_liste_taxon FROM '''||path||'std_listTaxon.csv'' HEADER CSV DELIMITER ''	'' ENCODING ''UTF8'';';
	FOR i in EXECUTE 'select "cdRef" from "'||libSchema||'".zz_log_liste_taxon' 
		LOOP  
		EXECUTE
			'INSERT INTO "'||libSchema||'".zz_log_liste_taxon_et_infra ("cdRefDemande", "nomValideDemande", "cdRefCite", "nomCompletCite","cdTaxsupCite","rangCite")
			select '''||i||''' as cdRefDemande, '''' as nomValideDemande, foo.* from 
			(WITH RECURSIVE hierarchie(cd_nom,nom_complet, cd_taxsup, rang) AS (
			SELECT cd_nom, nom_complet, cd_taxsup, rang
			FROM ref.taxref_v5 t1
			WHERE t1.cd_nom = '''||i||'''
			UNION
			SELECT t2.cd_nom, t2.nom_complet, t2.cd_taxsup, t2.rang
			FROM ref.taxref_v5 t2
			JOIN hierarchie h ON t2.cd_taxsup = h.cd_nom
			) SELECT * FROM hierarchie) as foo';
		end loop;
	EXECUTE 'update  "'||libSchema||'".zz_log_liste_taxon_et_infra set "nomValideDemande" = "nomValide" from "'||libSchema||'".zz_log_liste_taxon where zz_log_liste_taxon_et_infra."cdRefDemande"= zz_log_liste_taxon."cdRef" ' ;
	out."libLog" := jdd||' importé depuis '||path;
ELSE out."libLog" := 'Problème identifié dans le jdd (ni data, ni taxa,ni meta)'; END CASE;

--- Output&Log
out."libSchema" := libSchema;out."libChamp" := '-';out."libTable" := '-';out."typLog" := 'hub_import';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
RETURN next out; END; $BODY$  LANGUAGE plpgsql;

---------------------
--- Installe le hub en local
---------------------
CREATE OR REPLACE FUNCTION hub_install (libSchema varchar, path varchar) RETURNS varchar  AS 
$BODY$ DECLARE out zz_log%rowtype; BEGIN
CREATE TABLE IF NOT EXISTS "public".zz_log  ("libSchema" character varying,"libTable" character varying,"libChamp" character varying,"typLog" character varying,"libLog" character varying,"nbOccurence" character varying,"date" date);
PERFORM hub_clone(libSchema);
PERFORM hub_fsd('create',path);
PERFORM hub_fsd('update',path);
PERFORM hub_help('create',path);
PERFORM hub_help('update',path);
--- Output
RETURN 'Hub installé';
END;$BODY$ LANGUAGE plpgsql;


---------------------
--- Récupération d'un jeu de données depuis la partie propre vers la partie temporaire
---------------------
CREATE OR REPLACE FUNCTION hub_pull(source varchar, destination varchar, jdd varchar) RETURNS varchar AS 
$BODY$ DECLARE liste varchar array; DECLARE tableName varchar; BEGIN
EXECUTE 'SELECT ARRAY(SELECT tablename FROM pg_tables WHERE tablename LIKE ''temp_%'' AND schemaname = '''||source||''') ;' INTO liste;
FOREACH tableName IN ARRAY liste
	LOOP
	EXECUTE 'DELETE FROM "'||destination||'"."'||tableName||'" WHERE "cdJdd" = '''||jdd||'''; ';
	EXECUTE 'INSERT INTO "'||destination||'"."'||tableName||'" SELECT DISTINCT * FROM "'||source||'"."'||tableName||'" WHERE "cdJdd" = '''||jdd||''';';
	END LOOP;
RETURN 'Jeu de données '||jdd||' transféré de '||source||' à '||destination;
--- RETURN liste;
END; $BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Mise à jour de la partie propre
------------------------------------------
--- Ajouter la partie suppression? Ou hub_checkout
CREATE OR REPLACE FUNCTION hub_push(libSchema varchar,jdd varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE wheres varchar; DECLARE val varchar; DECLARE listeChamp varchar;  DECLARE compte integer; DECLARE tableListe varchar array; DECLARE libChamp varchar; DECLARE libTable varchar;  DECLARE champRef varchar;  DECLARE tableRef varchar; BEGIN
--- Variables
CASE 	WHEN jdd = 'meta' THEN 	champRef = 'cdJddPerm';	tableRef = 'metadonnees'; 
	WHEN jdd = 'data' THEN 	champRef = 'cdObsPerm';	tableRef = 'observation'; 
	WHEN jdd = 'taxa' THEN 	champRef = 'cdEntPerm';	tableRef = 'entite'; 
	ELSE 				champRef = ''; 		tableRef = '';END CASE;
--- Output
out."libSchema" := libSchema; out."libChamp" := '-'; out."typLog" := 'hub_push';SELECT CURRENT_TIMESTAMP INTO out."date";

--- Commandes
--- Pour les ajouts
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||jdd||' WHERE tbl_name <> ''releve'' '
	LOOP
	compte := 0;
	EXECUTE 'SELECT count(z."'||champRef||'") FROM "'||libSchema||'"."temp_'||tableRef||'" z LEFT JOIN "'||libSchema||'"."'||tableRef||'" a ON z."'||champRef||'" = a."'||champRef||'" WHERE a."'||champRef||'" IS NULL' INTO compte; 
	
	CASE WHEN (compte > 0) THEN
		EXECUTE 'INSERT INTO "'||libSchema||'"."'||libTable||'" SELECT z.* FROM "'||libSchema||'"."temp_'||libTable||'" z LEFT JOIN "'||libSchema||'"."'||tableRef||'" a ON z."'||champRef||'" = a."'||champRef||'" WHERE a."'||champRef||'" IS NULL';
		--- Log 
		out."libTable" := libTable; out."libLog" := 'Ajout de '||champRef; out."nbOccurence" := compte||' occurence(s)'; return next out;
	ELSE EXECUTE 'SELECT 1';
	END CASE;	
	END LOOP;

--- Modification
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||jdd||' WHERE tbl_name <> ''releve'' '
	LOOP
	val := null;
	wheres := 'WHERE 1=1';
	FOR libChamp in EXECUTE 'SELECT cd FROM ref.fsd_'||jdd||' WHERE tbl_name = '''||libTable||''''
		LOOP wheres := wheres||' OR a."'||libChamp||'"::varchar <> b."'||libChamp||'"::varchar';
		listeChamp := '"'||libChamp||' = b."'||libChamp||'",';
		END LOOP;
	EXECUTE 'SELECT string_agg("'||champRef||'",'','') FROM "'||libSchema||'"."temp_'||libTable||'" a JOIN "'||libSchema||'"."'||libTable||'" b ON a."'||champRef||'" = b."'||champRef||'" '||wheres||';' INTO val;
	val := rtrim(val,',');
	CASE WHEN (compte > 0) THEN
		EXECUTE 'UPDATE "'||libSchema||'"."'||libTable||'" SET '||listeChamp||' FROM (SELECT * FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||champRef||'" IN ('||val||'))';
		out."libTable" := libTable; out."libLog" := 'Modification sur la table '||libTable; out."nbOccurence" := compte||' occurence(s)'; return next out;
	ELSE EXECUTE 'SELECT 1';
	END CASE;	
	END LOOP;
--- Log général
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''',''-'',''-'',''hub_push'',''-'',''-'','''||out."date"||''');';
END;$BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Création des référentiels
------------------------------------------
CREATE OR REPLACE FUNCTION hub_ref(typAction varchar, path varchar = '/home/hub/00_ref/') RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype; DECLARE flag1 integer; DECLARE flag2 integer; DECLARE champFonction varchar; DECLARE libTable varchar; DECLARE delimitr varchar; DECLARE structure varchar; BEGIN
--- Output
out."libSchema" := '-';out."libTable" := '-';out."libChamp" := '-';out."typLog" := 'hub_ref';out."nbOccurence" := 1; SELECT CURRENT_TIMESTAMP INTO out."date";
---Variables
DROP TABLE IF  EXISTS public.ref_meta;CREATE TABLE public.ref_meta(id varchar, delimitr varchar, structure varchar, CONSTRAINT ref_meta_pk PRIMARY KEY(id));
INSERT INTO public.ref_meta VALUES 
('fsd_meta',';','(id serial NOT NULL, tbl_order integer, tbl_name character varying, pos character varying, cd character varying, lib character varying, format character varying,obligation character varying, unicite character varying, regle character varying, CONSTRAINT fsd_meta_pkey PRIMARY KEY (id))'),
('fsd_data',';','(id serial NOT NULL, tbl_order integer, tbl_name character varying, pos character varying, cd character varying, lib character varying, format character varying,obligation character varying, unicite character varying, regle character varying, CONSTRAINT fsd_data_pkey PRIMARY KEY (id))'),
('fsd_taxa',';','(id serial NOT NULL, tbl_order integer, tbl_name character varying, pos character varying, cd character varying, lib character varying, format character varying,obligation character varying, unicite character varying, regle character varying, CONSTRAINT fsd_taxa_pkey PRIMARY KEY (id))'),
('help',',','("id" varchar,"type" varchar,"description" varchar, "etat" varchar, "amelioration" varchar, CONSTRAINT pk_help PRIMARY KEY ("id"))'),
('help_var',';','("id" varchar,"description" varchar, "valeurs" varchar, "hub_checkout" varchar,"hub_clear" varchar,"hub_clone" varchar,"hub_diff" varchar,"hub_drop" varchar,"hub_export" varchar,"hub_extract" varchar,"hub_help" varchar,"hub_idPerm" varchar,"hub_import" varchar,"hub_install" varchar,"hub_pull" varchar,"hub_push" varchar,"hub_ref" varchar,"hub_verif" varchar,"hub_verif_all" varchar,CONSTRAINT pk_help_var PRIMARY KEY ("id"))'),
('taxref_v2','\t','("ogc_fid" integer, "regne" character varying, "phylum" character varying, "classe" character varying, "ordre" character varying, "famille" character varying, cd_nom character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, cd_ref character varying, nom_valide character varying, rang character varying, nom_vern character varying, nom_vern_eng character varying, fr character varying, mar character varying, gua character varying, smsb character varying, gf character varying, spm character varying, reu character varying, may character varying, taaf character varying, nom_complet_sans_date character varying, CONSTRAINT refv20_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v3','\t','(ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, smsb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, nc character varying, wf character varying, pf character varying, cli character varying, nom_complet character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv30_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v4','\t','(ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, sm character varying, sb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, pf character varying, nc character varying, wf character varying, cli character varying, aphia_id character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv40_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v5','\t', '(ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, sm character varying, sb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, pf character varying, nc character varying, wf character varying, cli character varying, url character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv50_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v6','\t', '(ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, sm character varying, sb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, pf character varying, nc character varying, wf character varying, cli character varying, url character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv60_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v7','\t','( ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, group1_inpn character varying, group2_inpn character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, sm character varying, sb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, pf character varying, nc character varying, wf character varying, cli character varying, url character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv70_utf8_pk PRIMARY KEY (ogc_fid))'),
('taxref_v8','\t','( ogc_fid integer, regne character varying, phylum character varying, classe character varying, ordre character varying, famille character varying, group1_inpn character varying, group2_inpn character varying, cd_nom character varying, cd_taxsup character varying, cd_ref character varying, rang character varying, lb_nom character varying, lb_auteur character varying, nom_complet character varying, nom_valide character varying, nom_vern character varying, nom_vern_eng character varying, habitat character varying, fr character varying, gf character varying, mar character varying, gua character varying, sm character varying, sb character varying, spm character varying, may character varying, epa character varying, reu character varying, taaf character varying, pf character varying, nc character varying, wf character varying, cli character varying, url character varying, nom_complet_html character varying, nom_complet_sans_date character varying, CONSTRAINT taxrefv80_utf8_pk PRIMARY KEY (ogc_fid))')
;

--- Commandes 
CASE WHEN typAction = 'drop' THEN	--- Suppression
	EXECUTE 'SELECT DISTINCT 1 FROM information_schema.schemata WHERE schema_name = ''ref''' INTO flag1;
	CASE WHEN flag1 = 1 THEN DROP SCHEMA IF EXISTS ref CASCADE; out."libLog" := 'Shema ref supprimé';RETURN next out;
	ELSE out."libLog" := 'Schéma ref inexistant';RETURN next out;END CASE;
WHEN typAction = 'delete' THEN	--- Suppression
	EXECUTE 'SELECT DISTINCT 1 FROM information_schema.schemata WHERE schema_name = ''ref''' INTO flag1;
	CASE WHEN flag1 = 1 THEN
		FOR libTable IN EXECUTE 'SELECT id FROM public.ref_meta'
		LOOP EXECUTE 'SELECT DISTINCT 1 FROM pg_tables WHERE schemaname = ''ref'' AND tablename = '''||libTable||''';' INTO flag2;
		CASE WHEN flag2 = 1 THEN 
			EXECUTE 'DROP TABLE ref."'||libTable||'" CASCADE';  out."libLog" := 'Table '||libTable||' supprimée';RETURN next out;
		ELSE out."libLog" := 'Table '||libTable||' inexistante';
		END CASE;
		END LOOP;
	ELSE out."libLog" := 'Schéma ref inexistant';RETURN next out;END CASE;
WHEN typAction = 'create' THEN	--- Creation
	EXECUTE 'SELECT DISTINCT 1 FROM information_schema.schemata WHERE schema_name =  ''ref''' INTO flag1;
	CASE WHEN flag1 = 1 THEN out."libLog" := 'Schema ref déjà créés';RETURN next out;ELSE CREATE SCHEMA "ref"; out."libLog" := 'Schéma ref créés';RETURN next out;END CASE;
	--- Tables
	FOR libTable IN EXECUTE 'SELECT id FROM public.ref_meta'
		LOOP EXECUTE 'SELECT DISTINCT 1 FROM pg_tables WHERE schemaname = ''ref'' AND tablename = '''||libTable||''';' INTO flag2;
		CASE WHEN flag2 = 1 THEN 
			out."libLog" := libTable||' a déjà été créée' ;RETURN next out;
		ELSE EXECUTE 'SELECT structure FROM public.ref_meta WHERE id = '''||libTable||'''' INTO structure;
		EXECUTE 'SELECT delimitr FROM public.ref_meta WHERE id = '''||libTable||'''' INTO delimitr;
		EXECUTE 'CREATE TABLE ref.'||libTable||' '||structure||';'; out."libLog" := libTable||' créée';RETURN next out;
		EXECUTE 'COPY ref.'||libTable||' FROM '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER E'''||delimitr||''' ENCODING ''UTF8'';';
		out."libLog" := libTable||' : données importées';RETURN next out;
		END CASE;
		END LOOP;
WHEN typAction = 'update' THEN	--- Mise à jour
	EXECUTE 'SELECT DISTINCT 1 FROM information_schema.schemata WHERE schema_name =  ''ref''' INTO flag1;
	CASE WHEN flag1 = 1 THEN out."libLog" := 'Schema ref déjà créés';RETURN next out;ELSE CREATE SCHEMA "ref"; out."libLog" := 'Schéma ref créés';RETURN next out;END CASE;
	FOR libTable IN EXECUTE 'SELECT id FROM public.ref_meta'
		LOOP 
		EXECUTE 'SELECT DISTINCT 1 FROM pg_tables WHERE schemaname = ''ref'' AND tablename = '''||libTable||''';' INTO flag2;
		EXECUTE 'SELECT delimitr FROM public.ref_meta WHERE id = '''||libTable||'''' INTO delimitr;
		CASE WHEN flag2 = 1 THEN
			EXECUTE 'TRUNCATE ref.'||libTable;
			EXECUTE 'COPY ref.'||libTable||' FROM '''||path||'std_'||libTable||'.csv'' HEADER CSV DELIMITER E'''||delimitr||''' ENCODING ''UTF8'';';
			out."libLog" := 'Mise à jour de la table '||libTable;RETURN next out;
		ELSE out."libLog" := 'Les tables doivent être créée auparavant : SELECT * FROM hub_ref(''create'',path)';RETURN next out;
		END CASE;
	END LOOP;
ELSE out."libLog" := 'Action non reconnue';RETURN next out;
END CASE;
--- DROP TABLE public.ref_meta;
--- Log
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
END;$BODY$ LANGUAGE plpgsql;
------------------------------------------
--- Vérifications
------------------------------------------
CREATE OR REPLACE FUNCTION hub_verif(libSchema varchar, jdd varchar, typVerif varchar) RETURNS setof zz_log AS 
$BODY$ DECLARE out zz_log%rowtype;DECLARE typJdd varchar;DECLARE libTable varchar;DECLARE libChamp varchar;DECLARE typChamp varchar;DECLARE val varchar;DECLARE compte integer;BEGIN
--- Output
out."libSchema" := libSchema;out."typLog" := 'hub_verif';SELECT CURRENT_TIMESTAMP INTO out."date";
--- Variables
CASE WHEN jdd = 'data' OR jdd = 'taxa' THEN
	typJdd := Jdd;
	---
ELSE EXECUTE 'SELECT "typJdd" FROM "'||libSchema||'"."temp_metadonnees" WHERE "cdJdd" = '''||jdd||'''' INTO typJdd;
	---
END CASE;

--- Test concernant l'obligation
CASE WHEN (typVerif = 'obligation' OR typVerif = 'all') THEN
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd||' WHERE obligation = ''Oui'''
LOOP		
	FOR libChamp in EXECUTE 'SELECT cd FROM ref.fsd_'||typJdd||' WHERE tbl_name = '''||libTable||''' AND obligation = ''Oui'''
	LOOP		
		compte := 0;
		EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||libChamp||'" IS NULL' INTO compte;
		CASE WHEN (compte > 0) THEN
			--- log
			out."libTable" := libTable; out."libChamp" := libChamp;out."libLog" := 'Champ obligatoire non renseigné'; out."nbOccurence" := compte||' occurence(s)'; return next out;
			EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
		ELSE EXECUTE 'SELECT 1';
		END CASE;
	END LOOP;
END LOOP;
ELSE SELECT 1;
END CASE;

--- Test concernant le typage des champs
CASE WHEN (typVerif = 'type' OR typVerif = 'all') THEN
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd||' WHERE obligation = ''Oui'''
	LOOP
	FOR libChamp in EXECUTE 'SELECT cd FROM ref.fsd_'||typJdd||' WHERE tbl_name = '''||libTable||''' AND obligation = ''Oui'''
	LOOP	
		compte := 0;
		EXECUTE 'SELECT type FROM ref.ddd WHERE cd = '''||libChamp||'''' INTO typChamp;
		IF (typChamp = 'int') THEN --- un entier
			EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||libChamp||'" !~ ''^\d+$''' INTO compte;
		ELSIF (typChamp = 'float') THEN --- un float
			EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||libChamp||'" !~ ''^\-?\d+\.\d+$''' INTO compte;
		ELSIF (typChamp = 'date') THEN --- une date
			EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||libChamp||'" !~ ''^[1,2][0-9]{2}[0-9]\-[0,1][0-9]\-[0-3][0-9]$'' AND "'||libChamp||'" !~ ''^[1,2][0-9]{2}[0-9]\-[0,1][0-9]$'' AND "'||libChamp||'" !~ ''^[1,2][0-9]{2}[0-9]$''' INTO compte;
		ELSIF (typChamp = 'boolean') THEN --- Boolean
			EXECUTE 'SELECT count(*) FROM "'||libSchema||'"."temp_'||libTable||'" WHERE "'||libChamp||'" !~ ''^t$'' AND "'||libChamp||'" !~ ''^f$''' INTO compte;
		ELSE --- le reste
			compte := 0;
		END IF;
		CASE WHEN (compte > 0) THEN
			--- log
			out."libTable" := libTable; out."libChamp" := libChamp;	out."libLog" := typChamp||' incorrecte' ; out."nbOccurence" := compte||' occurence(s)'; return next out;
			EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
		ELSE EXECUTE 'SELECT 1';
		END CASE;	
		END LOOP;
	END LOOP;
ELSE SELECT 1;
END CASE;

--- Test concernant les doublon
CASE WHEN (typVerif = 'doublon' OR typVerif = 'all') THEN
FOR libTable in EXECUTE 'SELECT DISTINCT tbl_name FROM ref.fsd_'||typJdd
	LOOP
	FOR libChamp in EXECUTE 'SELECT string_agg(''"''||cd||''"'',''||'') FROM ref.fsd_'||typJdd||' WHERE tbl_name = '''||libTable||''' AND unicite = ''Oui'''
		LOOP	
		compte := 0;
		EXECUTE 'SELECT count('||libChamp||') FROM "'||libSchema||'"."temp_'||libTable||'" GROUP BY '||libChamp||' HAVING COUNT('||libChamp||') > 1' INTO compte;
		CASE WHEN (compte > 0) THEN
			--- log
			out."libTable" := libTable; out."libChamp" := libChamp; out."libLog" := 'doublon(s)'; out."nbOccurence" := compte||' occurence(s)'; return next out;
			EXECUTE 'INSERT INTO "'||libSchema||'".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''','''||out."libTable"||''','''||out."libChamp"||''','''||out."typLog"||''','''||out."libLog"||''','''||out."nbOccurence"||''','''||out."date"||''');';
		ELSE EXECUTE 'SELECT 1';
		END CASE;
		END LOOP;
	END LOOP;
ELSE SELECT 1;
END CASE;
--- Log général
EXECUTE 'INSERT INTO "public".zz_log ("libSchema","libTable","libChamp","typLog","libLog","nbOccurence","date") VALUES ('''||out."libSchema"||''',''-'',''-'',''hub_verif'',''-'',''-'','''||out."date"||''');';
RETURN;END;$BODY$ LANGUAGE plpgsql;

------------------------------------------
--- Chainage des vérification
------------------------------------------
CREATE OR REPLACE FUNCTION hub_verif_all(libSchema varchar) RETURNS varchar AS 
$BODY$ BEGIN
TRUNCATE public.verification;
PERFORM hub_verif(libSchema,'meta','all');
PERFORM hub_verif(libSchema,'data','all');
PERFORM hub_verif(libSchema,'taxa','all');
RETURN 'Vérification réalisées (aller voir dans les tables zz_log)';END;
$BODY$ LANGUAGE plpgsql;



