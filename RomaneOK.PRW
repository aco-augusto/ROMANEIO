#include 'PROTHEUS.CH'

/*
------------------------------------------------------------------------------------------------------------
Função		: RomaneOK()
Tipo		: Função
Descrição	: Responsável por verificar se o romaneio está na fase 10 ou não
Chamado     : 
Parâmetros	: Código do romaneio, sequência e fase atual
Retorno		: Lógico (.T. = Está na fase 10, .F. = Não está na fase 10)
------------------------------------------------------------------------------------------------------------
Atualizações:
- 10/10/2019 - Augusto Oliveira - Construção inicial do fonte
------------------------------------------------------------------------------------------------------------
*/

User Function RomaneOK( cCodRom, cCodSeq ) //Função criada para validar se a separação já foi finalizada e autorizar a finalização do orçamento
    Local cFase       := ""
    // Default cFase   := "10"

    // cFase := FormatIn(cFase,"|")

    IF SELECT( 'qryZZ1' )
        qryZZ1->(DBCLOSEAREA())
    ENDIF

    //VERIFICA SE O ROMANEIO ESTÁ SENDO SEPARADO
    BEGINSQL ALIAS 'qryZZ1'
        SELECT TOP 1 ZZ1_FASE FASE
        FROM %table:ZZ2% (NOLOCK) Z2
        INNER JOIN %table:ZZ1% (NOLOCK) Z1 ON ZZ1_ROMAN = ZZ2_ROMAN AND ZZ1_SEQROM = ZZ2_SEQROM AND ZZ2_FILIAL = ZZ1_FILIAL
        WHERE Z2.ZZ2_FILIAL = %xFilial:ZZ2%
        AND Z2.D_E_L_E_T_ = ''  
        AND Z1.D_E_L_E_T_ = '' 
        // AND ZZ1_FASE IN %Exp:cFase%     //FASE DO ROMANEIO, ONDE 20 E 30 SÃO RESPECITIVAMENTE "EM SEPARAÇÃO" E "SEPARADO".
        AND Z2.ZZ2_ROMAN = %Exp:cCodRom%
        AND Z2.ZZ2_SEQROM = %Exp:cCodSeq%
    EndSQL

    cFase := qryZZ1->FASE

    qryZZ1->(DBCLOSEAREA())

Return cFase