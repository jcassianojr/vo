FUNCTION ConverteDataParaSQLite(dData AS DATE) AS STRING
    LOCAL cDToS AS STRING
    cDToS := DToS(dData) // Retorna YYYYMMDD
    RETURN SubStr(cDToS, 1, 4) + "-" + SubStr(cDToS, 5, 2) + "-" + SubStr(cDToS, 7, 2)
GLOBAL GLOoCONNECTION      AS SQLConnection  // used throughout the application; initiated on entry
GLOBAL GLOoSTATEMENT       AS SQLStatement
FUNCTION SqliteATTACH(cARQ)
LOCAL lRETU AS LOGIC
LOCAL oSTATEMENT AS SQLStatement
LOCAL cSQL AS STRING
LOCAL cARQCHAVE AS STRING
LOCAL cARQSQLITE AS STRING

cARQCHAVE:=cARQ+".DBF" //buscando com ponto .dbf para buscar na mesma chabe
cARQSQLITE:=PEGINIVAL(zCURINI,cARQCHAVE,"SQLITEARQ")
//alert(cARQSQLITE)
lRETU:=.f.
    IF gLOoCONNECTION:Connected

    	cSQL := "ATTACH DATABASE '"+ cARQSQLITE +"' AS "+cARQ
	     oSTATEMENT := SQLStatement{cSQL ,GLOoCONNECTION }
	     IF oSTATEMENT:Execute()
	       oSTATEMENT:FreeStmt( SQL_DROP  )
	       lRETU:=.f.
         ENDIF


    ENDIF
RETURN lRETU

FUNCTION C2SQL( uValue AS USUAL, cTipoSQL AS STRING ) AS STRING PASCAL
    LOCAL cRet  AS STRING
    LOCAL cDate AS STRING
    LOCAL cStr  AS STRING

    // Se não passar o banco, assume SQLITE por padrão (ou leia sua variável global)
    IF IsNil(cTipoSQL) .OR. Empty(cTipoSQL)
        cTipoSQL := "SQLITE"
    ELSE
        cTipoSQL := Upper(AllTrim(cTipoSQL))
    ENDIF

    DO CASE
        // 1. TRATAMENTO DE STRING / MEMO
        CASE IsString(uValue)
            cStr := AllTrim(uValue)

            // Tratamento de vazio para SQLite (Grava '' vazio em vez de NULL)
            IF Empty(cStr) .AND. cTipoSQL == "SQLITE"
                cRet := "''"
            ELSE
                // Escapa aspas simples duplicando-as (padrão SQL)
                cStr := StrTran(cStr, "'", "''")

                // Nota: O driver ODBC do SQLite geralmente converte ANSI para UTF-8 automaticamente.
                // Se notar acentuação errada, aplique aqui a sua função de conversão ANSI->UTF8.
                cRet := "'" + cStr + "'"
            ENDIF

        // 2. TRATAMENTO DE DATA
        CASE IsDate(uValue)
            // No VO a data vazia é comparada com NULL_DATE
            IF uValue == NULL_DATE
                IF cTipoSQL == "SQLITE"
                    cRet := "''"
                ELSE
                    cRet := "NULL"
                ENDIF
            ELSE
                // Converte a data do VO para a string padrão "YYYY-MM-DD"
                cDate := DToS(uValue)
                cRet  := "'" + SubStr(cDate, 1, 4) + "-" + SubStr(cDate, 5, 2) + "-" + SubStr(cDate, 7, 2) + "'"
            ENDIF

        // 3. TRATAMENTO DE NÚMEROS (Inteiros e Decimais)
        CASE IsNumeric(uValue)
            // Converte para string tirando os espaços
            cStr := AllTrim(AsString(uValue))
            // VO usa a configuração regional do Windows (vírgula decimal).
            // O SQL exige Ponto. Trocamos a vírgula por ponto obrigatoriamente:
            cStr := StrTran(cStr, ",", ".")
            cRet := cStr

        // 4. TRATAMENTO DE LÓGICOS (Boolean)
        CASE IsLogic(uValue)
            IF cTipoSQL == "SQLITE"
                // SQLite usa 1 para .T. e 0 para .F.
                cRet := IIf(uValue, "1", "0")
            ELSE
                // Outros bancos legados podem preferir a string
                cRet := IIf(uValue, "1", "0") // Altere para ".T." / ".F." se seu banco Oracle/MSSQL exigir
            ENDIF

        // 5. TRATAMENTO DE VALORES NULOS / NÃO DEFINIDOS (NIL)
        CASE IsNil(uValue)
            IF cTipoSQL == "SQLITE"
                cRet := "''"
            ELSE
                cRet := "NULL"
            ENDIF

        // 6. QUALQUER OUTRO TIPO DESCONHECIDO (Blindagem)
        OTHERWISE
            cRet := IIf(cTipoSQL == "SQLITE", "''", "NULL")

    ENDCASE

    RETURN cRet
FUNCTION SqliteTableList() AS ARRAY STRICT
	LOCAL aReturn AS ARRAY
	LOCAL oTables AS XSQLSelect
	// returns an array list of all the tables in the database
	oTables := XSQLSelect{ "SELECT name FROM sqlite_master WHERE type='table'", GLOoCONNECTION }
	oTables:GoTop()
	aReturn := {}
	WHILE !oTables:EoF
		AAdd( aReturn, oTables:FIELDGET(#NAME) )
		oTables:Skip(1)
	ENDDO
	oTables:Close()
  RETURN aReturn

FUNCTION SqlitePack() AS LOGIC
   LOCAL oStmt AS SQLStatement

   IF MDG( "Implantar configuracao de performace" )
      SqliteOptimize()
   ENDIF

   IF !Empty( GLOoCONNECTION )
      oStmt := SQLStatement{ , GLOoCONNECTION }

//    MDT( "Otimizando índices..." )
      oStmt:SQLString := "PRAGMA optimize"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP ) // Necessário antes de novo comando

  //  MDT( "Executando VACUUM (PACK)..." )
      oStmt:SQLString := "VACUUM"
      IF oStmt:Execute()
    //   MDT( "Processo concluído com sucesso." )
      ENDIF

      oStmt:FreeStmt( SQL_DROP )
   ENDIF
RETURN .T.

FUNCTION SqliteOptimize()
   LOCAL oStmt AS SQLStatement

   IF !Empty( GLOoCONNECTION )
      oStmt := SQLStatement{ , GLOoCONNECTION }

      // Lista de comandos: FreeStmt executado após cada comando para resetar o cursor

      oStmt:SQLString := "PRAGMA temp_store = MEMORY"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )

      oStmt:SQLString := "PRAGMA cache_size = 2000"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )

      oStmt:SQLString := "PRAGMA journal_mode = WAL"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )

      oStmt:SQLString := "PRAGMA synchronous = NORMAL"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )

      oStmt:SQLString := "PRAGMA auto_vacuum = INCREMENTAL"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )

      oStmt:SQLString := "PRAGMA incremental_vacuum"
      oStmt:Execute()
      oStmt:FreeStmt( SQL_DROP )
   ENDIF
RETURN .T.
FUNCTION SqliteZap( cTableName AS STRING ) AS LOGIC STRICT
   LOCAL lReturn := FALSE AS LOGIC
   LOCAL oStmt   AS SQLStatement

   // Verifica se o nome foi fornecido e se a conexão global está ativa
   IF !Empty( cTableName ) .AND. !Empty( GLOoCONNECTION )

      // Instancia o SQLStatement com a conexão global
      oStmt := SQLStatement{ , GLOoCONNECTION }

      // Monta o comando usando a string recebida
      oStmt:SQLString := "DELETE FROM " + cTableName

      // Executa a operação
      IF oStmt:Execute()
         lReturn := TRUE
      ENDIF

      // Libera o recurso do statement
      oStmt:FreeStmt( SQL_DROP )

   ENDIF

RETURN lReturn
