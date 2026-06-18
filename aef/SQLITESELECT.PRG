CLASS XSQLSelect INHERIT SQLSelect
    // Sua classe já herda de SQLSelect nativamente no seu fonte
    PROTECT aCustomStruct AS ARRAY

METHOD FieldName(nPos) CLASS XSQLSelect
    RETURN Symbol2String( SELF:FieldSym(nPos) )

// Retorna o objeto FieldSpec correspondente à coluna.
// É aqui que matamos o problema do SQLite! Se o driver falhar, nós criamos um dinâmico.
METHOD GoTop() CLASS XSQLSelect
    RETURN SUPER:GoTop()

METHOD GoBottom() CLASS XSQLSelect
    RETURN SUPER:GoBottom()

METHOD Skip(nReg) CLASS XSQLSelect
    LOCAL nPara AS INT
    nPara := IF(IsNil(nReg), 1, nReg)
    SUPER:Skip(nPara)
    RETURN !SELF:EOF

ACCESS EOF CLASS XSQLSelect
    RETURN SUPER:EOF

ACCESS BOF CLASS XSQLSelect
    RETURN SUPER:BOF

// =====================================================================
// 3. MÉTODOS DE ACESSO AOS DADOS (Intercepta o controle visual da tela)
// =====================================================================

METHOD Init(cSQL, oConnection) CLASS XSQLSelect
    SELF:BuildCustomStruct(cSQL)
//    alert(CSQL)
    cSQL := SELF:InjetaCastAutomatico(cSQL)
 //   alert(CSQL)
    SUPER:Init(cSQL, oConnection)
    SELF:Execute()


    RETURN SELF

METHOD XSkip( nSkip ) CLASS XSQLSelect
  // IF YOU'RE GETTING AN ERROR THAT POINTS TO SKIP(), it's probably because of a FIELDGET(# error
  // (at least it was today 6-20-2015).  Check the fields in both the code and in the selection
	Default( @nSkip, 1)
	IF SELF:EoF
		RETURN FALSE
	ELSE
		SELF:Skip( nSkip )
	ENDIF
  RETURN TRUE
METHOD DBSTRUCT() CLASS XSQLSelect
    // Se a nossa matriz customizada já estiver populada, o Form/Browser vai ler ela!
    IF SELF:aCustomStruct != NULL_ARRAY .AND. ALen(SELF:aCustomStruct) > 0
        RETURN SELF:aCustomStruct
    ENDIF

    // Fallback caso seja uma query interna administrativa vazia
    RETURN SUPER:DbStruct

// =====================================================================
// UTILIZANDO A SUA FUNÇÃO PRÓPRIA DE MAPEAMENTO
// =====================================================================
METHOD FieldInfoalert() CLASS XSQLSelect
    LOCAL nLen    AS DWORD
    LOCAL i       AS DWORD
    LOCAL aField  AS ARRAY
    LOCAL cInfo   AS STRING

    // Verifica se a estrutura customizada já foi gerada
    IF SELF:aCustomStruct == NULL_ARRAY .OR. ALen(SELF:aCustomStruct) == 0
        // Se por algum motivo estiver vazia, tenta forçar a geração antes de checar
        SELF:BuildCustomStruct()
    ENDIF

    nLen := ALen(SELF:aCustomStruct)

    IF nLen == 0
        alert("Aviso: A estrutura 'aCustomStruct' está totalmente vazia!")
        RETURN FALSE
    ENDIF

    // --- LOOP DE CHECAGEM DA DIRETAMENTE NA CUSTOM STRUCT ---
    FOR i := 1 TO nLen
        // Captura o array de 4 posições da coluna atual { Nome, Tipo, Tamanho, Decimais }
        aField := SELF:aCustomStruct[i]

        // Monta a string de diagnóstico com o resultado final convertido
        cInfo := "[ESTRUTURA CUSTOMIZADA FINAL]"  + ;
                 " Posição: " + NTrim(i) + ;
                 " Nome do Campo: " + aField[DBS_NAME]  + ;
                 " Tipo: " + aField[DBS_TYPE]  + ;
                 " Tamanho (Len): " + NTrim(aField[DBS_LEN])  + ;
                 " Decimais (Dec): " + NTrim(aField[DBS_DEC])

        // Exibe o Alert na tela para você auditar a tipagem que vai para o Form
        alert( cInfo )
    NEXT

    RETURN TRUE

METHOD Status() CLASS XSQLSelect
    // Retorna um objeto SQLStatus vazio ou o da classe mãe para acalmar a janela
    RETURN SUPER:Status

METHOD Commit() CLASS XSQLSelect
    RETURN SUPER:Commit()

METHOD Rollback() CLASS XSQLSelect
    RETURN SUPER:Rollback()

METHOD GoTo(nRec) CLASS XSQLSelect
    // Tenta posicionar de forma absoluta usando a inteligência nativa da query,
    // mas retorna lógico para o Browser não disparar erro de Runtime.
    SUPER:GoTo(nRec)
    RETURN !SELF:EOF

METHOD FieldSym(uField) CLASS XSQLSelect
    LOCAL nPos AS DWORD
    IF IsNumeric(uField)
        nPos := uField
        IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
            RETURN AsSymbol(SELF:aCustomStruct[nPos, DBS_NAME])
        ENDIF
    ENDIF
    RETURN SUPER:FieldSym(uField)

METHOD FieldPos(uField) CLASS XSQLSelect
    LOCAL symCampo AS SYMBOL
    LOCAL nLen     AS DWORD
    LOCAL i        AS DWORD

    IF IsSymbol(uField)
        symCampo := uField
    ELSEIF IsString(uField)
        symCampo := AsSymbol(uField)
    ELSE
        RETURN SUPER:FieldPos(uField)
    ENDIF

    // Procura na nossa estrutura limpa vinda da PRAGMA
    IF SELF:aCustomStruct != NULL_ARRAY
        nLen := ALen(SELF:aCustomStruct)
        FOR i := 1 TO nLen
            IF AsSymbol(SELF:aCustomStruct[i, DBS_NAME]) == symCampo
                RETURN i
            ENDIF
        NEXT
    ENDIF

    RETURN SUPER:FieldPos(symCampo)

METHOD FieldHyperLabel(uField) CLASS XSQLSelect
    LOCAL nPos     AS DWORD
   // LOCAL symCampo AS SYMBOL
    LOCAL oHL      AS HyperLabel

    IF IsNumeric(uField)
        nPos := uField
    ELSE
        nPos := SELF:FieldPos(AsSymbol(uField))
    ENDIF

    IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
        // Cria um HyperLabel limpo com o nome real do campo detetado na PRAGMA
        oHL := HyperLabel{ AsSymbol(SELF:aCustomStruct[nPos, DBS_NAME]), SELF:aCustomStruct[nPos, DBS_NAME] }
        RETURN oHL
    ENDIF

    RETURN SUPER:FieldHyperLabel(uField)

METHOD FieldCount() CLASS XSQLSelect
    IF SELF:aCustomStruct != NULL_ARRAY .AND. ALen(SELF:aCustomStruct) > 0
        RETURN ALen(SELF:aCustomStruct)
    ENDIF
    RETURN SELF:FCount

ACCESS FCount CLASS XSQLSelect
    IF SELF:aCustomStruct != NULL_ARRAY .AND. ALen(SELF:aCustomStruct) > 0
        RETURN ALen(SELF:aCustomStruct)
    ENDIF
    RETURN SUPER:FCount


// 2. INFORMAÇÃO DE CAMPOS USANDO NÚMEROS DIRETOS (Resolve o tamanho zero do driver)
METHOD FieldInfo(kFieldInfoType, uField) CLASS XSQLSelect
    LOCAL nPos   AS DWORD
    LOCAL aField AS ARRAY

    IF IsSymbol(uField) .OR. IsString(uField)
        nPos := SELF:FieldPos(AsSymbol(uField))
    ELSE
        nPos := uField
    ENDIF

    IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
        aField := SELF:aCustomStruct[nPos]

        // 1=Name, 2=Type, 3=Length, 4=Decimals
        DO CASE
            CASE kFieldInfoType == 1
                RETURN aField[DBS_NAME]
            CASE kFieldInfoType == 2
                RETURN aField[DBS_TYPE]
            CASE kFieldInfoType == 3
                RETURN aField[DBS_LEN] // Força o CAVO a ver o tamanho real (Ex: 20)
            CASE kFieldInfoType == 4
                RETURN aField[DBS_DEC]
        ENDCASE
    ENDIF

    RETURN SUPER:FieldInfo(kFieldInfoType, uField)


// 3. GERAÇÃO DINÂMICA DO FIELDSPEC COM O TAMANHO REAL DA PRAGMA
METHOD FieldSpec(uField) CLASS XSQLSelect
    LOCAL nPos     AS DWORD
    LOCAL symCampo AS SYMBOL
    LOCAL aStruct  AS ARRAY

    IF IsSymbol(uField)
        symCampo := uField
    ELSEIF IsNumeric(uField)
        symCampo := SELF:FieldSym(uField)
    ELSE
        symCampo := AsSymbol(uField)
    ENDIF

    nPos := SELF:FieldPos(symCampo)

    IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
        aStruct := SELF:aCustomStruct[nPos]
        // O próprio construtor já amarra o tamanho correto da PRAGMA
        RETURN FieldSpec{ aStruct[DBS_NAME], aStruct[DBS_TYPE], aStruct[DBS_LEN], aStruct[DBS_DEC] }
    ENDIF

    RETURN SUPER:FieldSpec(uField)


METHOD FieldSpecPtr(uField) CLASS XSQLSelect
    RETURN SELF:FieldSpec(uField)


// 4. CAPTURA DOS VALORES DIRETAMENTE DO STATEMENT (Ignora o buffer truncado da classe mãe)
METHOD BuildCustomStruct(cSQLOriginal) CLASS XSQLSelect
    LOCAL cCamposVejam  AS STRING
    LOCAL cSQLUpper     AS STRING
    LOCAL nPosSelect    AS DWORD
    LOCAL nPosFrom      AS DWORD
    LOCAL aCamposCort   AS ARRAY
    LOCAL nLenCort      AS DWORD
    LOCAL oPragma       AS SQLSelect
    LOCAL cSQLPragma    AS STRING
    LOCAL cTabela       AS STRING
    LOCAL aPragmaStruct AS ARRAY
    LOCAL nLenPragma    AS DWORD
    LOCAL cFieldName    AS STRING
    LOCAL cFieldType    AS STRING
    LOCAL aTmpField     AS ARRAY
    LOCAL i, j          AS DWORD
    LOCAL cNomeLimpo    AS STRING
    LOCAL lAcheiPragma  AS LOGIC

    SELF:aCustomStruct := {}

    // 1. EXTRAÇÃO DO NOME DA TABELA PARA CONSULTAR A PRAGMA
    cSQLUpper := Upper(cSQLOriginal)
    nPosFrom  := At(" FROM ", cSQLUpper)
    IF nPosFrom == 0
        RETURN NIL
    ENDIF

    cTabela := SubStr(cSQLOriginal, nPosFrom + 6)
    cTabela := AllTrim(cTabela)
    IF " " $ cTabela
        cTabela := SubStr(cTabela, 1, At(" ", cTabela) - 1)
    ENDIF
    cTabela := StrTran(cTabela, "[", "")
    cTabela := StrTran(cTabela, "]", "")
    cTabela := StrTran(cTabela, ";", "")

    // 2. BUSCA TODOS OS METADADOS REAIS DA TABELA NO SQLITE
    cSQLPragma    := "PRAGMA table_info('" + cTabela + "');"
    oPragma       := SQLSelect{ cSQLPragma, GLOoCONNECTION }
    oPragma:Execute()
    oPragma:GoTop()

    aPragmaStruct := {}

    WHILE !oPragma:EOF
        cFieldName := AllTrim( oPragma:FIELDGET(#name) )
        cFieldType := AllTrim( oPragma:FIELDGET(#type) )

        IF !Empty(cFieldName) .AND. !Empty(cFieldType)
            aTmpField := geracampodbf(cFieldName, cFieldType, 0, 0, "SQLITE")

            IF ValType(aTmpField) == "A" .AND. ALen(aTmpField) == 4

                // Força o tipo para Data ("D") caso seja DATE no banco ou contenha termos de data
                // as vezes o nome tem a string data mais pode ser char ou outro tipo
                IF "DATE" $ Upper(cFieldType) //.OR. "DATA" $ Upper(cFieldName) .OR. "DT" $ Upper(cFieldName)
                    aTmpField[DBS_TYPE] := "D"
                    aTmpField[DBS_LEN]  := 8
                    aTmpField[DBS_DEC]  := 0
                ENDIF

                AAdd(aPragmaStruct, aTmpField)
            ENDIF
        ENDIF
        oPragma:Skip(1)
    ENDDO
    oPragma:Close()
    nLenPragma := ALen(aPragmaStruct)

    // 3. FATIAMENTO DOS CAMPOS SOLICITADOS NO SELECT
    nPosSelect   := At("SELECT ", cSQLUpper)
    cCamposVejam := SubStr(cSQLOriginal, nPosSelect + 7, nPosFrom - (nPosSelect + 7))
    cCamposVejam := AllTrim(cCamposVejam)

    IF cCamposVejam == "*"
        SELF:aCustomStruct := aPragmaStruct
        RETURN NIL
    ENDIF

    aCamposCort := {}
    DO WHILE "," $ cCamposVejam
        AAdd(aCamposCort, AllTrim(SubStr(cCamposVejam, 1, At(",", cCamposVejam) - 1)))
        cCamposVejam := SubStr(cCamposVejam, At(",", cCamposVejam) + 1)
    ENDDO
    AAdd(aCamposCort, AllTrim(cCamposVejam))
    nLenCort := ALen(aCamposCort)

    // 4. ALINHAMENTO PELA ORDEM EXATA DO SELECT
    FOR i := 1 TO nLenCort
        cNomeLimpo := aCamposCort[i]

        IF " as " $ Lower(cNomeLimpo)
            nPosFrom   := At(" AS ", Upper(cNomeLimpo))
            cNomeLimpo := SubStr(cNomeLimpo, 1, nPosFrom - 1)
            cNomeLimpo := AllTrim(cNomeLimpo)
        ENDIF
        IF "." $ cNomeLimpo
            cNomeLimpo := SubStr(cNomeLimpo, At(".", cNomeLimpo) + 1)
            cNomeLimpo := AllTrim(cNomeLimpo)
        ENDIF

        lAcheiPragma := FALSE

        FOR j := 1 TO nLenPragma
            IF Upper(aPragmaStruct[j, DBS_NAME]) == Upper(cNomeLimpo)
                AAdd(SELF:aCustomStruct, aPragmaStruct[j])
                lAcheiPragma := TRUE
                EXIT
            ENDIF
        NEXT

        IF !lAcheiPragma
            AAdd(SELF:aCustomStruct, { cNomeLimpo, "C", 20, 0 })
        ENDIF
    NEXT

    RETURN NIL
    METHOD InjetaCastAutomatico(cSQLOriginal) CLASS XSQLSelect
    LOCAL cCamposVejam  AS STRING
    LOCAL cRestoQuery   AS STRING
    LOCAL cNovoSelect   AS STRING
    LOCAL nPosSelect    AS DWORD
    LOCAL nPosFrom      AS DWORD
    LOCAL aCamposCort   AS ARRAY
    LOCAL nLenCort      AS DWORD
    LOCAL i, j          AS DWORD
    LOCAL cItemCampo    AS STRING
    LOCAL cNomeLimpo    AS STRING
    LOCAL lAcheiPragma  AS LOGIC
    LOCAL cType         AS STRING
    LOCAL nSize         AS DWORD
    LOCAL nLenStruct    AS DWORD
    LOCAL cSQLUpper     AS STRING

    IF SELF:aCustomStruct == NULL_ARRAY .OR. ALen(SELF:aCustomStruct) == 0
        RETURN cSQLOriginal
    ENDIF

    cSQLUpper  := Upper(cSQLOriginal)
    nPosSelect := At("SELECT ", cSQLUpper)
    nPosFrom   := At(" FROM ", cSQLUpper)

    IF nPosSelect == 0 .OR. nPosFrom == 0
        RETURN cSQLOriginal
    ENDIF

    cCamposVejam := SubStr(cSQLOriginal, nPosSelect + 7, nPosFrom - (nPosSelect + 7))
    cRestoQuery  := SubStr(cSQLOriginal, nPosFrom)
    cCamposVejam := AllTrim(cCamposVejam)

    cNovoSelect := "SELECT "
    nLenStruct  := ALen(SELF:aCustomStruct)

    // =========================================================================
    // CASO A: SELECT *
    // =========================================================================
    IF cCamposVejam == "*"
        FOR i := 1 TO nLenStruct
            cNomeLimpo := SELF:aCustomStruct[i, DBS_NAME]
            cType      := SELF:aCustomStruct[i, DBS_TYPE]
            nSize      := SELF:aCustomStruct[i, DBS_LEN]

            IF cType == "C"
                cNovoSelect += "CAST(" + cNomeLimpo + " AS VARCHAR(" + AllTrim(Str(nSize)) + ")) AS " + cNomeLimpo
            ELSEIF cType == "D"
                cNovoSelect += "CAST(" + cNomeLimpo + " AS VARCHAR(10)) AS " + cNomeLimpo
            ELSE
                cNovoSelect += cNomeLimpo
            ENDIF

            IF i < nLenStruct
                cNovoSelect += ", "
            ENDIF
        NEXT

        RETURN cNovoSelect + cRestoQuery
    ENDIF

    // =========================================================================
    // CASO B: CAMPOS ESPECÍFICOS
    // =========================================================================
    aCamposCort := {}
    DO WHILE "," $ cCamposVejam
        AAdd(aCamposCort, AllTrim(SubStr(cCamposVejam, 1, At(",", cCamposVejam) - 1)))
        cCamposVejam := SubStr(cCamposVejam, At(",", cCamposVejam) + 1)
    ENDDO
    AAdd(aCamposCort, AllTrim(cCamposVejam))

    nLenCort := ALen(aCamposCort)

    FOR i := 1 TO nLenCort
        cItemCampo := aCamposCort[i]

        IF "cast(" $ Lower(cItemCampo)
            cNovoSelect += cItemCampo
        ELSE
            cNomeLimpo := cItemCampo
            IF " as " $ Lower(cNomeLimpo)
                nPosFrom   := At(" AS ", Upper(cNomeLimpo))
                cNomeLimpo := SubStr(cNomeLimpo, 1, nPosFrom - 1)
                cNomeLimpo := AllTrim(cNomeLimpo)
            ENDIF
            IF "." $ cNomeLimpo
                cNomeLimpo := SubStr(cNomeLimpo, At(".", cNomeLimpo) + 1)
            ENDIF

            lAcheiPragma := FALSE
            FOR j := 1 TO nLenStruct
                IF Upper(SELF:aCustomStruct[j, DBS_NAME]) == Upper(cNomeLimpo)
                    cType        := SELF:aCustomStruct[j, DBS_TYPE]
                    nSize        := SELF:aCustomStruct[j, DBS_LEN]
                    lAcheiPragma := TRUE
                    EXIT
                ENDIF
            NEXT

            IF lAcheiPragma .AND. cType == "C"
                cNovoSelect += "CAST(" + cItemCampo + " AS VARCHAR(" + AllTrim(Str(nSize)) + ")) AS " + cNomeLimpo
            ELSEIF lAcheiPragma .AND. cType == "D"
                cNovoSelect += "CAST(" + cItemCampo + " AS VARCHAR(10)) AS " + cNomeLimpo
            ELSE
                cNovoSelect += cItemCampo
            ENDIF
        ENDIF

        IF i < nLenCort
            cNovoSelect += ", "
        ENDIF
    NEXT

    RETURN cNovoSelect + " " + cRestoQuery


    METHOD FIELDGET(uField) CLASS XSQLSelect
    LOCAL nPos   AS DWORD
    LOCAL uVal   AS USUAL
    LOCAL cType  AS STRING
    LOCAL nLen   AS DWORD

    IF IsSymbol(uField) .OR. IsString(uField)
        nPos := SELF:FieldPos(AsSymbol(uField))
    ELSE
        nPos := uField
    ENDIF

    IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
        cType := SELF:aCustomStruct[nPos, DBS_TYPE]
        nLen  := SELF:aCustomStruct[nPos, DBS_LEN]

        IF SELF:Statement != NULL_OBJECT
            BEGIN SEQUENCE
                uVal := SELF:Statement:GetColVal(nPos)
            END
        ENDIF

        // TRATAMENTO DE NULL: Se o campo for nulo no banco, limpa com base no tipo
        IF IsNil(uVal)
            IF cType == "C" ; RETURN Space(nLen) ; ENDIF
            IF cType == "N" ; RETURN 0 ; ENDIF
            IF cType == "D" ; RETURN NULL_DATE ; ENDIF
        ENDIF

        DO CASE
            CASE cType == "C"
                IF !IsString(uVal)
                    uVal := AsString(uVal)
                ENDIF
                RETURN PadR(AllTrim(uVal), nLen)

            CASE cType == "D"
                IF IsString(uVal)
                    uVal := AllTrim(uVal)
                    IF Empty(uVal) .OR. uVal == "0000-00-00"
                        RETURN NULL_DATE
                    ENDIF
                    RETURN SToD(StrTran(uVal, "-", ""))
                ENDIF
                RETURN uVal

            CASE cType == "N"
                IF IsString(uVal)
                    RETURN Val(uVal)
                ENDIF
                RETURN uVal
        ENDCASE
    ENDIF

    RETURN SUPER:FIELDGET(uField)


    METHOD FIELDPUT(uField, uValue) CLASS XSQLSelect
    LOCAL nPos  AS DWORD
    LOCAL cType AS STRING
    LOCAL cDToS AS STRING

    IF IsSymbol(uField) .OR. IsString(uField)
        nPos := SELF:FieldPos(AsSymbol(uField))
    ELSE
        nPos := uField
    ENDIF

    IF nPos > 0 .AND. nPos <= SELF:FieldCount()
        IF SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
            cType := SELF:aCustomStruct[nPos, DBS_TYPE]

            // Se o valor vindo da tela for NIL, normaliza antes de enviar
            IF IsNil(uValue)
                IF cType == "C" ; uValue := "" ; ENDIF
                IF cType == "N" ; uValue := 0 ; ENDIF
                IF cType == "D" ; uValue := NULL_DATE ; ENDIF
            ENDIF

            IF cType == "D" .AND. IsDate(uValue)
                IF Empty(uValue)
                    uValue := "" // Grava vazio no TEXT do SQLite para indicar sem data
                ELSE
                    cDToS  := DToS(uValue)
                    uValue := SubStr(cDToS, 1, 4) + "-" + SubStr(cDToS, 5, 2) + "-" + SubStr(cDToS, 7, 2)
                ENDIF

            ELSEIF cType == "C" .AND. IsString(uValue)
                uValue := AllTrim(uValue)
            ENDIF
        ENDIF

        RETURN SUPER:FIELDPUT(nPos, uValue)
    ENDIF

    RETURN SUPER:FIELDPUT(uField, uValue)
METHOD GetTableNameFromSql() CLASS XSQLSelect
    LOCAL cSql AS STRING
    LOCAL nPosFrom AS INT
    LOCAL nPosSpace AS INT
    LOCAL cTemp AS STRING
    LOCAL cTableName AS STRING

    // 1. Pega a SQL em maiúsculas para facilitar a busca
    cSql := Upper(SELF:SQLString)

    // 2. Localiza a posição do 'FROM'
    nPosFrom := At("FROM", cSql)

    IF nPosFrom > 0
        // 3. Pega o restante da string após o 'FROM' (mais 4 posições do próprio FROM)
        cTemp := AllTrim(SubStr(cSql, nPosFrom + 4))

        // 4. Se houver espaços após o nome da tabela (ex: "CLIENTES WHERE..."), pega apenas até o primeiro espaço
        nPosSpace := At(" ", cTemp)
        IF nPosSpace > 0
            cTableName := Left(cTemp, nPosSpace - 1)
        ELSE
            cTableName := cTemp
        ENDIF
    ENDIF

    // Remove parênteses caso a consulta seja um sub-select (opcional)
    cTableName := StrTran(cTableName, "(", "")

RETURN cTableName

METHOD XRecCount() CLASS XSQLSelect
    LOCAL nReturn      AS INT
    LOCAL oCountSelect AS SQLSelect
    LOCAL cCountSql    AS STRING

    nReturn  := 0
    // Monta a query utilizando a própria string do objeto como subquery.
    // Isso preserva todos os filtros (WHERE, JOINs, etc.) da consulta original.
    cCountSql := "SELECT count(*) AS XCOUNT FROM (" + SELF:SQLString + ") AS TmpCount"

    // Instancia usando o padrão SQLSelect{cSQL, oConnection}
    // Utilizamos a GLOoCONNECTION global que você já utiliza na aplicação
    oCountSelect := SQLSelect{ cCountSql, GLOoCONNECTION }

    // Executa e avança para o primeiro registro
    oCountSelect:Execute()
    oCountSelect:GoTop()

    // Recupera o valor usando o método FIELDGET que você já possui
    // O nome 'XCOUNT' foi definido no alias da subquery acima
    nReturn := oCountSelect:FIELDGET(#XCOUNT)

    // Fecha o objeto para liberar os recursos do SQLite imediatamente
    oCountSelect:Close()

RETURN nReturn
