METHOD FieldSpec(uField) CLASS XSQLTable
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
        RETURN FieldSpec{ aStruct[DBS_NAME], aStruct[DBS_TYPE], aStruct[DBS_LEN], aStruct[DBS_DEC] }
    ENDIF
    RETURN SUPER:FieldSpec(uField)

METHOD FieldHyperLabel(uField) CLASS XSQLTable
    LOCAL nPos AS DWORD
    LOCAL oHL  AS HyperLabel

    IF IsNumeric(uField)
        nPos := uField
    ELSE
        nPos := SELF:FieldPos(AsSymbol(uField))
    ENDIF

    IF nPos > 0 .AND. SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
        oHL := HyperLabel{ AsSymbol(SELF:aCustomStruct[nPos, DBS_NAME]), SELF:aCustomStruct[nPos, DBS_NAME] }
        RETURN oHL
    ENDIF
    RETURN SUPER:FieldHyperLabel(uField)

// =====================================================================
// 3. ENTRADA E SAÍDA DE DADOS TRATADA (Garante conversões perfeitas)
// =====================================================================
METHOD GetAsString( sField, cType, nLength, nDecimal ) CLASS XSQLTable
    LOCAL cReturn AS STRING
    DO CASE
    CASE cType = "C"
        cReturn := SELF:FIELDGET( sField )
    CASE cType = "L"
        cReturn := LTOC( SELF:FIELDGET( sField ) )
    CASE cType = "D"
        cReturn := IIF( nLength < 10, DToS(SELF:FIELDGET( sField )) , DToC( SELF:FIELDGET( sField ) ) )
    CASE cType = "N"
        cReturn := Str3( SELF:FIELDGET( sField ), nLength, nDecimal )
    OTHERWISE
        cReturn := Space(1)
    ENDCASE
    RETURN cReturn

CLASS XSQLTable INHERIT SQLTable
    PROTECT cUpdate        AS STRING
    PROTECT cUnique        AS STRING
    PROTECT cFileNameAbbrv AS STRING
    PROTECT aCustomStruct  AS ARRAY // Guarda o dicionário real lido via PRAGMA
    PROTECT cPrimaryKey    AS STRING
    PROTECT aUltimoRegistro AS ARRAY

// =====================================================================
// 1. CONSTRUTOR INTERCEPTADO (Lê as definições reais da tabela)
// =====================================================================
METHOD Init(cTableName, oConnection) CLASS XSQLTable
    SUPER:Init(cTableName, oConnection)

    // Alimenta a nossa estrutura limpa buscando os metadados reais da tabela
    SELF:BuildCustomStruct(SELF:Name)

    SELF:PegueChavePrimaria()
    SELF:aUltimoRegistro := {}

    RETURN SELF

// =====================================================================
// 2. RETORNO DE MATRIZES E PROPRIEDADES (Corrigido sem FieldCount)
// =====================================================================
METHOD DBSTRUCT() CLASS XSQLTable
    // Se a nossa matriz customizada já estiver populada, o Form/Browser vai ler ela!
    IF SELF:aCustomStruct != NULL_ARRAY .AND. ALen(SELF:aCustomStruct) > 0
        RETURN SELF:aCustomStruct
    ENDIF
    RETURN SUPER:DbStruct

ACCESS FCount CLASS XSQLTable
    // Intercepta a propriedade oficial que o CAVO usa para contar as colunas da tabela
    IF SELF:aCustomStruct != NULL_ARRAY .AND. ALen(SELF:aCustomStruct) > 0
        RETURN ALen(SELF:aCustomStruct)
    ENDIF
    RETURN SUPER:FCount

METHOD BuildCustomStruct(cTabela) CLASS XSQLTable
    LOCAL oPragma       AS SQLSelect
    LOCAL cSQLPragma    AS STRING
    LOCAL aPragmaStruct AS ARRAY
    LOCAL cFieldName    AS STRING
    LOCAL cFieldType    AS STRING
    LOCAL aTmpField     AS ARRAY

    SELF:aCustomStruct := {}

    cTabela := AllTrim(cTabela)
    cTabela := StrTran(cTabela, "[", "")
    cTabela := StrTran(cTabela, "]", "")
    cTabela := StrTran(cTabela, ";", "")

    // Consulta os metadados físicos diretamente na PRAGMA do SQLite
    cSQLPragma := "PRAGMA table_info('" + cTabela + "');"

    // GLOoCONNECTION deve ser a sua conexão ODBC global ativa
    oPragma := SQLSelect{ cSQLPragma, GLOoCONNECTION }
    oPragma:Execute()
    oPragma:GoTop()

    aPragmaStruct := {}

    WHILE !oPragma:EOF
        cFieldName := AllTrim( oPragma:FIELDGET(#name) )
        cFieldType := AllTrim( oPragma:FIELDGET(#type) )

        IF !Empty(cFieldName) .AND. !Empty(cFieldType)
            // Traduz a coluna do SQLite usando a sua função padrão de conversão
            aTmpField := geracampodbf(cFieldName, cFieldType, 0, 0, "SQLITE")

            IF ValType(aTmpField) == "A" .AND. ALen(aTmpField) == 4

                // BLINDAGEM DE DATA: Força o layout "D" com tamanho 8 caso seja DATE ou possua indicador no nome
                IF "DATE" $ Upper(cFieldType) .OR. "DATA" $ Upper(cFieldName) .OR. "DT" $ Upper(cFieldName)
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

    IF ALen(aPragmaStruct) > 0
        SELF:aCustomStruct := aPragmaStruct
    ENDIF

    RETURN NIL

// =====================================================================
// 4. TRATAMENTO DE INTERCEPTAÇÃO DE LEITURA (FIELDGET) COM SUPORTE A NULL
// =====================================================================
METHOD FIELDGET(uField) CLASS XSQLTable
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

        // Lê o dado bruto persistido na linha atual do recordset
        uVal := SUPER:FIELDGET(nPos)

        // PROTEÇÃO CONTRA NULL: Se o banco de dados retornar nulo, normaliza o tipo
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
                    // Filtra strings de data sem preenchimento do SQLite
                    IF Empty(uVal) .OR. uVal == "0000-00-00"
                        RETURN NULL_DATE
                    ENDIF
                    // Reconverte "YYYY-MM-DD" para o objeto DATE do CAVO usando SToD("YYYYMMDD")
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

// =====================================================================
// 5. TRATAMENTO DE INTERCEPTAÇÃO DE GRAVAÇÃO (FIELDPUT) COM SUPORTE A NULL
// =====================================================================
METHOD FIELDPUT(uField, uValue) CLASS XSQLTable
    LOCAL nPos  AS DWORD
    LOCAL cType AS STRING
    LOCAL cDToS AS STRING

    IF IsSymbol(uField) .OR. IsString(uField)
        nPos := SELF:FieldPos(AsSymbol(uField))
    ELSE
        nPos := uField
    ENDIF

    // Verifica os limites com base na contagem de campos reais da tabela mãe
    IF nPos > 0 .AND. nPos <= SUPER:FCount

        IF SELF:aCustomStruct != NULL_ARRAY .AND. nPos <= ALen(SELF:aCustomStruct)
            cType := SELF:aCustomStruct[nPos, DBS_TYPE]

            // Se o controle de tela enviar um valor nulo (NIL), resolve antes de mandar pro SQLite
            IF IsNil(uValue)
                IF cType == "C" ; uValue := "" ; ENDIF
                IF cType == "N" ; uValue := 0 ; ENDIF
                IF cType == "D" ; uValue := NULL_DATE ; ENDIF
            ENDIF

            IF cType == "D" .AND. IsDate(uValue)
                IF Empty(uValue)
                    // Passa string vazia '' para o SQLite acionar o DEFAULT '' definido na base
                    uValue := ""
                ELSE
                    // Transforma o objeto DATE do CAVO em string ISO "YYYY-MM-DD"
                    cDToS  := DToS(uValue)
                    uValue := SubStr(cDToS, 1, 4) + "-" + SubStr(cDToS, 5, 2) + "-" + SubStr(cDToS, 7, 2)
                ENDIF

            ELSEIF cType == "C" .AND. IsString(uValue)
                uValue := AllTrim(uValue)
            ENDIF
        ENDIF

        // Repassa os dados já normalizados e formatados para a gravação da classe mãe
        RETURN SUPER:FIELDPUT(nPos, uValue)
    ENDIF

    RETURN SUPER:FIELDPUT(uField, uValue)

// =====================================================================
// MÉTODOS COMPLEMENTARES PRESENVADOS
// =====================================================================
METHOD FieldSym(nPos) CLASS XSQLTable
    IF SELF:aCustomStruct != NULL_ARRAY .AND. nPos > 0 .AND. nPos <= ALen(SELF:aCustomStruct)
        RETURN AsSymbol(SELF:aCustomStruct[nPos, DBS_NAME])
    ENDIF
    RETURN SUPER:FieldSym(nPos)

METHOD FieldName(nPos) CLASS XSQLTable
    IF SELF:aCustomStruct != NULL_ARRAY .AND. nPos > 0 .AND. nPos <= ALen(SELF:aCustomStruct)
        RETURN SELF:aCustomStruct[nPos, DBS_NAME]
    ENDIF
    RETURN SUPER:FieldName(nPos)

METHOD Locate( sField, cValue ) CLASS XSQLTable
    LOCAL lreturn := FALSE AS LOGIC
    SELF:GoTop()
    WHILE !SELF:EoF
        IF SELF:FIELDGET(sField) == cValue
            lreturn := TRUE
            EXIT
        ENDIF
        SELF:Skip(1)
    ENDDO
    RETURN lreturn

METHOD FieldPos(uField) CLASS XSQLTable
    LOCAL nPos AS DWORD
    LOCAL i    AS DWORD
    LOCAL cSeek AS STRING

    // Correção: No CAVO usa-se IsNumeric() em vez de IsNumber()
    IF IsNumeric(uField)
        RETURN uField
    ENDIF

    IF IsSymbol(uField)
        cSeek := Upper(Symbol2String(uField))
    ELSEIF IsString(uField)
        cSeek := Upper(AllTrim(uField))
    ELSE
        RETURN 0
    ENDIF

    // Procura primeiro no nosso dicionário customizado alinhado
    IF SELF:aCustomStruct != NULL_ARRAY
        FOR i := 1 TO ALen(SELF:aCustomStruct)
            IF Upper(SELF:aCustomStruct[i, DBS_NAME]) == cSeek
                RETURN i
            ENDIF
        NEXT
    ENDIF

    // Fallback seguro usando a classe pai
    nPos := SUPER:FieldPos(uField)
    RETURN nPos
METHOD ExecuteSql( cStatement ) CLASS XSQLTable
    LOCAL oStmt   AS SQLStatement
    LOCAL lReturn AS LOGIC

    // Cria, executa e monitora o sucesso da declaração SQL
    oStmt := SQLStatement{ cStatement, GLOoCONNECTION }
    lReturn := oStmt:Execute()

    RETURN lReturn

METHOD CopyStructure( cNewTable, lcopiaindex ) CLASS XSQLTable
    LOCAL oSelect    AS SQLSelect
    LOCAL cStatement AS STRING
    LOCAL lReturn    AS LOGIC
    LOCAL cSqlIndex  AS STRING
    LOCAL cNewIndex  AS STRING

    Default( @lcopiaindex, FALSE )
    cStatement := Space(0)

    // 1. COPIA A ESTRUTURA DA TABELA PRINCIPAL
    oSelect := SQLSelect{ "SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name = '" + SELF:Name + "'", SELF:Connection }
    oSelect:Execute()
    oSelect:GoTop()

    cStatement := oSelect:FIELDGET(#sql)
    oSelect:Close()

    IF Empty(cStatement)
        RETURN FALSE
    ENDIF

    // Reconstrói o começo do comando trocando o nome da tabela antiga pela nova
    cStatement := "CREATE TABLE " + AllTrim(cNewTable) + SubStr2( cStatement, At( "(", cStatement ) )

    // Cria a nova tabela vazia
    lReturn := SELF:ExecuteSql(cStatement)

    // 2. COPIA OS ÍNDICES CASO O PARÂMETRO SEJA VERDADEIRO E A TABELA TENHA SIDO CRIADA
    IF lReturn .AND. lcopiaindex
        oSelect := SQLSelect{ "SELECT sql, name FROM sqlite_master WHERE type = 'index' AND tbl_name = '" + SELF:Name + "' AND sql IS NOT NULL", SELF:Connection }
        oSelect:Execute()
        oSelect:GoTop()

        WHILE !oSelect:EOF
            cSqlIndex := oSelect:FIELDGET(#sql) // Ex: "CREATE INDEX idx_lc_documento ON lc (documento)"

            IF !Empty(cSqlIndex)
                // Substitui de forma segura o sufixo/nome da tabela antiga pelo nome da nova tabela
                // Para evitar colisões de nomes de índices duplicados no banco, ajustamos o nome do índice também
                cNewIndex := StrTran( cSqlIndex, " ON " + AllTrim(SELF:Name), " ON " + AllTrim(cNewTable) )
                cNewIndex := StrTran( cNewIndex, "idx_" + AllTrim(Lower(SELF:Name)), "idx_" + AllTrim(Lower(cNewTable)) )

                // Dispara a criação do índice correspondente na nova tabela
                SELF:ExecuteSql(cNewIndex)
            ENDIF

            oSelect:Skip(1)
        ENDDO
        oSelect:Close()
    ENDIF

    RETURN lReturn
METHOD PegueChavePrimaria() CLASS XSQLTable
    LOCAL oSelect     AS SQLSelect
    LOCAL cSQLPragma  AS STRING
    LOCAL cTabela     AS STRING

    // Inicializa a variável da classe limpa
    SELF:cPrimaryKey := Space(0)

    cTabela := AllTrim(SELF:Name)
    cTabela := StrTran(cTabela, "[", "")
    cTabela := StrTran(cTabela, "]", "")
    cTabela := StrTran(cTabela, ";", "")

    // Consulta os metadados físicos diretamente na PRAGMA do SQLite
    cSQLPragma := "PRAGMA table_info('" + cTabela + "');"

    oSelect := SQLSelect{ cSQLPragma, SELF:Connection }
    oSelect:Execute()
    oSelect:GoTop()

    WHILE !oSelect:EOF
        // Se a coluna 'pk' na PRAGMA for maior que 0, encontramos a chave
        IF Val( AsString( oSelect:FIELDGET(#pk) ) ) > 0
            // ATRIBUIÇÃO DIRETA: Grava direto na propriedade da classe
            SELF:cPrimaryKey := AllTrim( AsString( oSelect:FIELDGET(#name) ) )
            EXIT
        ENDIF
        oSelect:Skip()
    ENDDO
    oSelect:Close()

    // Retorna NIL (ou True/False se preferir monitorar o sucesso)
    RETURN NIL
ACCESS PrimaryKey CLASS XSQLTable
    RETURN SELF:cPrimaryKey

// =====================================================================
// 2. PROPRIEDADE ASSIGN (Permite alterar de fora usando := )
// =====================================================================
ASSIGN PrimaryKey(cNovoCampo) CLASS XSQLTable
    IF IsString(cNovoCampo)
        SELF:cPrimaryKey := AllTrim(cNovoCampo)
    ENDIF
    RETURN SELF:cPrimaryKey

// =====================================================================
// 3. MÉTODO TRADICIONAL PARA FORÇAR A CHAVE (Se preferir via chamada de função)
// =====================================================================
METHOD SetPrimaryKey(cNovoCampo) CLASS XSQLTable
    IF IsString(cNovoCampo)
        SELF:cPrimaryKey := AllTrim(cNovoCampo)
        RETURN TRUE
    ENDIF
    RETURN FALSE
METHOD DeleteSQL() CLASS XSQLTable
    LOCAL cPK      AS STRING
    LOCAL uPKValue AS USUAL
    LOCAL cSql     AS STRING

    cPK := SELF:PrimaryKey

    // Proteção: Se a tabela não tem chave primária, aborta para não excluir tudo
    IF Empty(cPK)
        RETURN FALSE
    ENDIF

    // Pega o valor da chave no registro atual da tabela
    uPKValue := SELF:FIELDGET(cPK)
    IF IsNil(uPKValue)
        RETURN FALSE
    ENDIF

    // Monta o DELETE protegendo o valor com a sua função C2SQL
    cSql := "DELETE FROM " + SELF:Name + " WHERE " + cPK + " = " + C2SQL(uPKValue,"SQLITE")

    // Aproveita o método ExecuteSql que aprimoramos anteriormente
    RETURN SELF:ExecuteSql(cSql)

   // =====================================================================
// ATUALIZAÇÃO DIRETA POR SQL (Equivalente ao REPLACE do DBF)
// =====================================================================
METHOD ReplaceSQL( aCampos, aValores ) CLASS XSQLTable
    LOCAL cPK      AS STRING
    LOCAL uPKValue AS USUAL
    LOCAL cSql     AS STRING
    LOCAL cSet     AS STRING
    LOCAL i        AS DWORD

    // Valida se enviou matrizes do mesmo tamanho
    IF ValType(aCampos) != "A" .OR. ValType(aValores) != "A" .OR. ALen(aCampos) != ALen(aValores) .OR. ALen(aCampos) == 0
        RETURN FALSE
    ENDIF

    cPK := SELF:PrimaryKey
    IF Empty(cPK)
        RETURN FALSE
    ENDIF

    uPKValue := SELF:FIELDGET(cPK)
    IF IsNil(uPKValue)
        RETURN FALSE
    ENDIF

    cSet := ""
    // Monta a string "campo1 = valor1, campo2 = valor2"
    FOR i := 1 TO ALen(aCampos)
        IF i > 1
            cSet += ", "
        ENDIF
        cSet += aCampos[i] + " = " + C2SQL(aValores[i],"SQLITE")
    NEXT

    // Monta o UPDATE apontando exclusivamente para a chave primária atual
    cSql := "UPDATE " + SELF:Name + " SET " + cSet + " WHERE " + cPK + " = " + C2SQL(uPKValue,"SQLITE")

    RETURN SELF:ExecuteSql(cSql)
TEXTBLOCK readme.XSQLTable.SQLite
// =====================================================================
// INSERÇÃO DIRETA POR SQL (Equivalente ao APPEND BLANK + REPLACE)
// =====================================================================
   LOCAL oTabela  AS XSQLTable
LOCAL aCampos  AS ARRAY
LOCAL aValores AS ARRAY

oTabela := XSQLTable{ "clientes", GLOoCONNECTION }

aCampos  := { "NOME", "CIDADE" } // Repara que não passaste a Primary Key
aValores := { "MANUEL", "PORTO" }

// A variável vai receber o número exato que o SQLite acabou de inventar!
nNovoClienteID := oTabela:AppendSQL( aCampos, aValores )

IF IsNumeric( nNovoClienteID )
    ? "Cliente inserido com sucesso! O novo código gerado é: ", nNovoClienteID
ENDIF

// 2. ATUALIZANDO O REGISTRO ATUAL (Para onde o cursor estiver apontando):
aCampos  := { "LIMITE" }
aValores := { 2500.00 }
oTabela:ReplaceSQL( aCampos, aValores )

// 3. APAGANDO O REGISTRO ATUAL:
oTabela:DeleteSQL()


IF oTabela:SeekSQL( "DOCUMENTO = '12345'" )
    // ACERTOU! O ponteiro já "estacionou" no registro.
    // Você NÃO chama GetRowSQL(). Você lê direto da tabela:

    cNomeCli := oTabela:FIELDGET("NOME")
    nLimite  := oTabela:FIELDGET("LIMITE")

    // Ou usando a sintaxe de acesso direto do VO:
    // cNomeCli := oTabela:NOME
ENDIF

IF oTabela:SeekSQL( "CODIGO = 100" )
    // A tela já acompanhou o registro. Lê o dado do cursor:
    nSaldoAtual := oTabela:FIELDGET("SALDO")

    // Trava o registro, altera via VO e salva
    IF oTabela:RLOCK()
        oTabela:FIELDPUT("SALDO", nSaldoAtual + 500.00)
        oTabela:Commit()
        oTabela:Unlock()
    ENDIF
ENDIF
METHOD AppendSQL( aCampos, aValores ) CLASS XSQLTable
    LOCAL cSql     AS STRING
    LOCAL cCols    AS STRING
    LOCAL cVals    AS STRING
    LOCAL i        AS DWORD
    LOCAL lHasPK   AS LOGIC
    LOCAL cPK      AS STRING
    LOCAL uNewID   AS USUAL
    LOCAL oSelect  AS SQLSelect

    // Valida matrizes
    IF ValType(aCampos) != "A" .OR. ValType(aValores) != "A" .OR. ALen(aCampos) != ALen(aValores) .OR. ALen(aCampos) == 0
        RETURN 0
    ENDIF

    cPK    := SELF:PrimaryKey
    lHasPK := FALSE
    cCols  := ""
    cVals  := ""

    // Desmembra os arrays construindo a sintaxe do INSERT INTO
    FOR i := 1 TO ALen(aCampos)
        IF i > 1
            cCols += ", "
            cVals += ", "
        ENDIF

        cCols += aCampos[i]
        cVals += C2SQL(aValores[i],"SQLITE")

        // Verifica se tu passaste a chave primária manualmente na matriz
        IF !Empty(cPK) .AND. Upper(AllTrim(aCampos[i])) == Upper(cPK)
            lHasPK := TRUE
        ENDIF
    NEXT

    cSql := "INSERT INTO " + SELF:Name + " (" + cCols + ") VALUES (" + cVals + ")"

    // Se a inserção for bem-sucedida...
    IF SELF:ExecuteSql(cSql)

        // 1. Se for uma Importação (tu forçaste a chave manualmente), retorna apenas TRUE
        IF lHasPK .OR. Empty(cPK)
            RETURN 0
        ENDIF

        // 2. Se for um Append Novo (o SQLite gerou o Auto-Increment), vamos descobrir o ID!
        // last_insert_rowid() é a função nativa do SQLite que devolve o último ID gerado nesta conexão
        cSql := "SELECT last_insert_rowid() AS new_id"
        oSelect := SQLSelect{ cSql, SELF:Connection }
        oSelect:Execute()
        oSelect:GoTop()

        IF !oSelect:EOF
            uNewID := oSelect:FIELDGET(#new_id)
        ENDIF
        oSelect:Close()

        // Devolve o número do novo registro criado!
        RETURN uNewID
    ENDIF

    RETURN 0
METHOD GetRowSQL( cWhere ) CLASS XSQLTable
    LOCAL oSelect    AS SQLSelect
    LOCAL cSql       AS STRING
    LOCAL aRowValues AS ARRAY
    LOCAL nFCount    AS DWORD
    LOCAL i          AS DWORD

    aRowValues := {}

    // Se o Where for omitido ou vazio, traz a tabela toda (ou use proteção)
    IF IsNil( cWhere )
        cWhere := ""
    ELSE
        cWhere := AllTrim( cWhere )
        IF !Empty( cWhere ) .AND. ! ( Upper( Left( cWhere, 5 ) ) == "WHERE" )
            cWhere := "WHERE " + cWhere
        ENDIF
    ENDIF

    // Monta o SELECT dinâmico baseado no nome da tabela atual
    cSql := "SELECT * FROM " + SELF:Name + " " + cWhere

    // Executa a query usando a conexão ativa da própria tabela
    oSelect := SQLSelect{ cSql, SELF:Connection }
    oSelect:Execute()
    oSelect:GoTop()

    // Se encontrou dados no recordset, popula a matriz
    IF !oSelect:EOF
        // Descobre a quantidade de colunas que vieram do banco
        nFCount := oSelect:FCount

        // Dimensiona a matriz para o tamanho exato de colunas
        aRowValues := ArrayCreate( nFCount )

        FOR i := 1 TO nFCount
            // Coleta o valor aplicando os tratamentos de tipo (e protege nulos se necessário)
            aRowValues[i] := oSelect:FIELDGET( i )
        NEXT
    ENDIF

SELF:aUltimoRegistro := aRowValues
    oSelect:Close()

    RETURN aRowValues
METHOD SeekSQL( cWhere ) CLASS XSQLTable
    LOCAL uRegistro AS USUAL // Mudamos de ARRAY para USUAL para evitar a checagem estrita
    LOCAL cPK       AS STRING
    LOCAL nPosPK    AS DWORD
    LOCAL uID       AS USUAL
    LOCAL lAchou    AS LOGIC

    cPK := SELF:PrimaryKey
    IF Empty(cPK)
        RETURN FALSE
    ENDIF

    // 1. Usa o Send() para forçar a chamada dinâmica ignorando os avisos da IDE
    uRegistro := Send( SELF, #GetRowSQL, cWhere )

    // Valida se o retorno realmente veio como matriz e se achou algo
    IF !IsArray( uRegistro ) .OR. ALen( uRegistro ) == 0
        RETURN FALSE // Não existe no banco
    ENDIF

    // 2. Descobre em qual posição da matriz está o valor da Chave Primária
    nPosPK := SELF:FieldPos( cPK )
    IF nPosPK == 0
        RETURN FALSE
    ENDIF

    // Captura o ID real que o banco de dados retornou (usando a matriz uRegistro)
    uID := uRegistro[ nPosPK ]

    // 3. Agora varre o cursor local (DataServer) para posicionar a tela
    lAchou := FALSE

    SELF:SuspendNotification()

    SELF:GoTop()
    WHILE !SELF:EOF
        IF SELF:FIELDGET( cPK ) == uID
            lAchou := TRUE
            EXIT
        ENDIF
        SELF:Skip()
    ENDDO

    IF !lAchou
        SELF:GoTop()
    ENDIF

    SELF:ResetNotification()
    SELF:Notify( NOTIFYRECORDCHANGE )

    RETURN lAchou
ACCESS RegistroSQL CLASS XSQLTable
        RETURN SELF:aUltimoRegistro
METHOD SqlCreatefromMaster( cNewTable, lcopiaindex ) CLASS XSQLTable
    LOCAL oSelect    AS SQLSelect
    LOCAL cStatement AS STRING
    LOCAL cSqlIndex  AS STRING

    Default( @lcopiaindex, FALSE )
    cStatement := Space(0)

    // 1. COPIA A ESTRUTURA DA TABELA PRINCIPAL
    oSelect := SQLSelect{ "SELECT sql FROM sqlite_master WHERE type = 'table' AND tbl_name = '" + SELF:Name + "'", SELF:Connection }
    oSelect:Execute()
    oSelect:GoTop()

    cStatement := oSelect:FIELDGET(#sql)
    oSelect:Close()

    IF Empty(cStatement)
        RETURN ""
    ENDIF

    cStatement += "; "


    // 2. COPIA OS ÍNDICES CASO O PARÂMETRO SEJA VERDADEIRO E A TABELA TENHA SIDO CRIADA
    IF  lcopiaindex
        oSelect := SQLSelect{ "SELECT sql, name FROM sqlite_master WHERE type = 'index' AND tbl_name = '" + SELF:Name + "' AND sql IS NOT NULL", SELF:Connection }
        oSelect:Execute()
        oSelect:GoTop()

        WHILE !oSelect:EOF
            cSqlIndex := oSelect:FIELDGET(#sql) // Ex: "CREATE INDEX idx_lc_documento ON lc (documento)"

            IF !Empty(cSqlIndex)
               cStatement += cSqlIndex +"; "
             ENDIF

            oSelect:Skip(1)
        ENDDO
        oSelect:Close()
    ENDIF

    RETURN cStatement
METHOD XRecCount( cWhere  ) CLASS XSQLTable
    LOCAL nReturn  AS INT
    LOCAL oSelect  AS XSQLSelect
    LOCAL cStatement AS STRING

    // O SELECT COUNT(*) retorna uma única linha com uma coluna (neste caso, apelidada de XCOUNT)
    cStatement := "SELECT count(*) AS XCOUNT FROM " + SELF:Name

    IF !Empty( cWhere )
        cStatement += " WHERE " + cWhere
    ENDIF

    // Instanciamos o XSQLSelect passando a conexão global.
    // O construtor do XSQLSelect (conforme visto em seus arquivos) já executa o SELECT.
    oSelect := XSQLSelect{ cStatement, GLOoCONNECTION }

    // Recupera o valor da coluna definida no SELECT
    nReturn := oSelect:FIELDGET(#XCOUNT)

    // Fecha o cursor para liberar os recursos do SQLite
    oSelect:Close()

RETURN nReturn

METHOD Zap() CLASS XSQLTable
    LOCAL lReturn AS LOGIC
    LOCAL oStmt   AS SQLStatement
    LOCAL cSql    AS STRING


   lReturn  := FALSE
    // 1. Monta o comando de exclusão total usando o nome da própria tabela
    cSql := "DELETE FROM " + SELF:Name

    // 2. Utiliza o SQLStatement com a conexão global do seu sistema
    oStmt := SQLStatement{ cSql, GLOoCONNECTION }

    // 3. Executa a operação
    IF oStmt:Execute()
        SELF:Commit() // Garante que a transação seja persistida, se necessário
        lReturn := TRUE
    ENDIF

    // 4. Liberação obrigatória para evitar bloqueios ou vazamento de recursos no SQLite
    oStmt:FreeStmt( SQL_DROP )

RETURN lReturn
