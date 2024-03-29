#include 'PROTHEUS.CH'

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: RomaneOK()
Tipo		: Fun��o
Descri��o	: Respons�vel por verificar se o romaneio est� na fase 10 ou n�o
Chamado     : 
Par�metros	: C�digo do romaneio, sequ�ncia e fase atual
Retorno		: L�gico (.T. = Est� na fase 10, .F. = N�o est� na fase 10)
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 10/10/2019 - Augusto Oliveira - Constru��o inicial do fonte
------------------------------------------------------------------------------------------------------------
*/

User Function RomaneOK( cCodRom, cCodSeq )�//Fun��o�criada�para�validar�se�a�separa��o�j�foi�finalizada�e�autorizar�a�finaliza��o�do�or�amento
    Local cFase       := ""
    // Default cFase   := "10"

    // cFase := FormatIn(cFase,"|")

    IF SELECT( 'qryZZ1' )
        qryZZ1->(DBCLOSEAREA())
    ENDIF

    //VERIFICA SE O ROMANEIO EST� SENDO SEPARADO
    BEGINSQL ALIAS 'qryZZ1'
        SELECT TOP 1 ZZ1_FASE FASE
        FROM %table:ZZ2% (NOLOCK) Z2
        INNER JOIN %table:ZZ1% (NOLOCK) Z1 ON ZZ1_ROMAN = ZZ2_ROMAN AND ZZ1_SEQROM = ZZ2_SEQROM AND ZZ2_FILIAL = ZZ1_FILIAL
        WHERE Z2.ZZ2_FILIAL = %xFilial:ZZ2%
        AND Z2.D_E_L_E_T_ = ''  
        AND Z1.D_E_L_E_T_ = '' 
        // AND ZZ1_FASE IN %Exp:cFase%     //FASE DO ROMANEIO, ONDE 20 E 30 S�O RESPECITIVAMENTE "EM SEPARA��O" E "SEPARADO".
        AND Z2.ZZ2_ROMAN = %Exp:cCodRom%
        AND Z2.ZZ2_SEQROM = %Exp:cCodSeq%
    EndSQL

    cFase := qryZZ1->FASE

    qryZZ1->(DBCLOSEAREA())

Return cFase