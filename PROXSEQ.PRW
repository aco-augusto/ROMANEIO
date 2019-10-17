/*
------------------------------------------------------------------------------------------------------------
Função		: PROXSEQ(cCodRom)
Tipo		: Função
Descrição	: Recebe o código do romaneio e devolve o maior valor da sequência
Chamado     : Ao gravar um novo romaneio
Parâmetros	: cCodRom: Código do romaneio que está sendo gravado
Retorno		: cSeqRom: Próximo código da sequência do romaneio disponível
------------------------------------------------------------------------------------------------------------
Atualizações:
- 16/10/2019 - Augusto Oliveira - Construção inicial do fonte
------------------------------------------------------------------------------------------------------------
*/

User Function PROXSEQ(cCodRom)
    Local cSeqRom	:= ""

    BEGINSQL ALIAS 'qryZZ2'
        SELECT MAX(ZZ2_SEQROM) SEQROM
        FROM %table:ZZ2% (NOLOCK) Z2
        WHERE ZZ2_FILIAL = %xFilial:ZZ1%
        AND Z2.D_E_L_E_T_ = ''
        AND ZZ2_ROMAN = %Exp:cCodRom%
    ENDSQL

    cSeqRom	:= If (Empty(qryZZ2->(SEQROM)), Soma1(qryZZ2->(SEQROM)), qryZZ2->(SEQROM))

    qryZZ2->(dbCloseArea())
Return cSeqRom