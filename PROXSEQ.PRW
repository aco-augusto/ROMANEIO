/*
------------------------------------------------------------------------------------------------------------
Fun��o		: PROXSEQ(cCodRom)
Tipo		: Fun��o
Descri��o	: Recebe o c�digo do romaneio e devolve o maior valor da sequ�ncia
Chamado     : Ao gravar um novo romaneio
Par�metros	: cCodRom: C�digo do romaneio que est� sendo gravado
Retorno		: cSeqRom: Pr�ximo c�digo da sequ�ncia do romaneio dispon�vel
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 16/10/2019 - Augusto Oliveira - Constru��o inicial do fonte
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