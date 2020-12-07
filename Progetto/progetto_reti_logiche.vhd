----------------------------------------------------------------------------------
-- ______ _____ - ______ - ______ 
--
-- Politecnico di Milano - Scuola di Ingegneria Industriale e dell'Informazione
-- Corso di Ingegneria Informatica
-- A.A. 2019/2020
--
-- Prova finale di Reti Logiche
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity project_reti_logiche is
    Port ( 
        i_clk       : in STD_LOGIC; -- Clock in ingresso
        i_start     : in STD_LOGIC; -- Segnale di start
        i_rst       : in STD_LOGIC; -- Segnale di reset
        i_data      : in STD_LOGIC_VECTOR (7 downto 0); -- Vettore di lettura della memoria
        o_address   : out STD_LOGIC_VECTOR (15 downto 0); -- Vettore di selezione della memoria
        o_done      : out STD_LOGIC; -- Segnale di fine elaborazione
        o_en        : out STD_LOGIC; -- Enable della memoria
        o_we        : out STD_LOGIC; -- Write enable della memoria
        o_data      : out STD_LOGIC_VECTOR (7 downto 0) -- Vettore di scrittura sulla memoria
    ); 
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    -- Segnali che rappresentano uscite di registri
    signal o_regnext    : STD_LOGIC_VECTOR (3 downto 0); -- Indirizzo in RAM della prossima WZ da analizzare
    signal o_regin      : STD_LOGIC_VECTOR (7 downto 0); -- Indirizzo da codificare
    signal o_regwz      : STD_LOGIC_VECTOR (7 downto 0); -- WZ in lettura
    signal o_regsub     : STD_LOGIC_VECTOR (7 downto 0); -- Uscita dal sottrattore di WZ e addr
    
    signal o_muxwz      : STD_LOGIC_VECTOR (6 downto 0); -- Uscita del multiplexer che decide la codifica dell'indirizzo
    -- Controllo e uscita del multiplexer che decide il valore da caricare in regnext
    signal mux_nxt      : STD_LOGIC; 
    signal o_muxnxt     : STD_LOGIC_VECTOR (3 downto 0); 
    signal o_muxint     : STD_LOGIC_VECTOR (3 downto 0);    
    -- Controllo del multiplexer che decide il valore di o_address
    signal mux_mem      : STD_LOGIC; 
    signal o_muxmem     : STD_LOGIC_VECTOR (3 downto 0);

    -- Segnali di enable dei registri
    signal regnext_load : STD_LOGIC;
    signal regin_load   : STD_LOGIC;
    signal regwz_load   : STD_LOGIC;
    signal regsub_load  : STD_LOGIC;
    
    -- Segnali di enable reali
    signal regnext_enable: STD_LOGIC;
    signal regsub_enable : STD_LOGIC;

    -- Valore della WZ in cui si trova l'indirizzo da codificare    
    signal wzoff        : STD_LOGIC_VECTOR(2 downto 0);
    
    signal is_in        : STD_LOGIC; -- Flag, indica la presenza dell'indirizzo in una WZ
    signal onehot       : STD_LOGIC_VECTOR (3 downto 0); -- Per portare in uscita la codifica 1-hot dell'offset 
    signal end_reset    : STD_LOGIC; -- Flag, reset aggiuntivo a fine esecuzione

    type S is (
        S0, -- Stato iniziale / reset
        S1, -- Avvio e richiesta addr 
        S2, -- Memorizzazione regin e richiesta prima wz
        S3, -- Caricamento wz0
        S4, -- Analisi a pipeline piena
        S5, -- Analisi con gestione indirizzi disabilitata
        S6, -- Analisi con gestione input disabilitata
        S7, -- Output
        S8  -- Completo
    );
    signal cur_state, next_state : S;

    begin
    -- COMPONENTI MACCHINA A STATI
    
    -- Inizializzazione / reset / passaggio allo stato successivo
    process(i_clk, i_rst)
        begin
        if(i_rst = '1') then
            cur_state <= S0;
        elsif i_clk'event and i_clk = '1' then
            cur_state <= next_state;
        end if;
    end process;
    
    -- Descrizione delle transizioni della FSM
    process(cur_state, i_start, is_in, o_regnext)
        begin
   --     next_state <= cur_state;
        case cur_state is
            when S0 =>
                if (i_start = '1') then
                    next_state <= S1;
                    else next_state <=S0;
                end if;
            when S1 =>
                next_state <= S2;
            when S2 =>
                next_state <= S3;
            when S3 =>
                next_state <= S4;
            when S4 =>
                if (is_in = '1') then
                    next_state <= S7;
                elsif(o_regnext = "0111") then
                    next_state <= S5;
                    else next_state<=S4;
                end if;
            when S5 =>
                if (is_in = '1') then
                    next_state <= S7;
                else
                    next_state <= S6;
                end if;
            when S6 =>
                next_state <= S7;      
            when S7 =>
                next_state <= S8;
            when S8 =>
                if(i_start = '0') then
                    next_state <= S0;
                    else next_state<=S8;
                end if;
        end case;
    end process;
    
    process(cur_state)
        begin
        -- Inizializzazione segnali FSM
        o_en <= '0';
        o_we <= '0';
        o_done <= '0';
        
        mux_nxt <= '0';
        mux_mem <= '0';
        
        regnext_load <= '0';
        regin_load <= '0';
        regwz_load <= '0';
        regsub_load <= '0';
        
        end_reset <= '0';
        
        case cur_state is
            when S0 =>
            
            -- Inizializzazione
            when S1 =>
                o_en <= '1';
                
                regnext_load <= '1';
            
            when S2 =>
                o_en <= '1';
                mux_nxt <= '1';
                
                regnext_load <= '1';
                regin_load <= '1';
                
            when S3 =>
                o_en <= '1';
                mux_nxt <= '1'; 
                
                regnext_load <= '1'; 
                regwz_load <= '1';
                
            -- Analisi    
            when S4 =>
                o_en <= '1';
                mux_nxt <= '1';
                
                regnext_load <= '1';
                regwz_load <= '1';
                regsub_load <= '1';
                
            when S5 =>
                o_en <= '1';
                mux_nxt <= '1';
                mux_mem <= '1';
                
                regnext_load <= '1';
                regwz_load <= '1';
                regsub_load <= '1';
                
            when S6 =>
                o_en <= '1';
                mux_nxt <= '1';
                mux_mem <= '1';
                
                regnext_load <= '1';
                regsub_load <= '1';
                
            -- Output
            when S7 =>
                o_en <= '1';
                o_we <= '1';
                mux_mem <= '1';
                
            when S8 =>
                o_done <= '1';
                end_reset <= '1';
        end case;
    end process;

    -- COMPONENTI DATAPATH
    
    -- Gestione indirizzi
    
    -- Multiplexer in entrata a regnext
    with mux_nxt select 
        o_muxnxt <= "0000" when '0',
            o_regnext + '1' when '1',
            "XXXX" when others;
    
    -- Enable reale di regnext
    regnext_enable <= regnext_load AND (NOT is_in);
    
    -- Controllo di regnext (registro contatore / contenente l'indirizzo di memoria cui accedere)
    process(i_clk,i_rst,end_reset)
        begin
        if(i_rst = '1' OR end_reset = '1') then
            o_regnext <= "0000";
        elsif i_clk'event and i_clk = '1' then
            if(regnext_enable = '1') then
                o_regnext <= o_muxnxt;
            end if;
        end if; 
    end process;
    
    -- Multiplexer in serie per selezionare o_address
    with mux_nxt select 
        o_muxint <= "1000" when '0',
            o_regnext when '1',
            "XXXX" when others;
    with mux_mem select 
        o_muxmem <= o_muxint when '0', 
            "1001" when '1',
            "XXXX" when others;
            
    -- Costruzione o_address
    o_address <= "000000000000" & o_muxmem;
            
    --Gestione input    
        
    -- Controllo di regin (registro contente l'indirizzo da codificare)
    process(i_clk,i_rst,end_reset)
        begin
        if(i_rst = '1' OR end_reset = '1') then
            o_regin <= "00000000";
        elsif i_clk'event and i_clk = '1' then
            if(regin_load = '1') then
                o_regin <= i_data;
            end if;
        end if; 
    end process;
        
    -- Controllo di regwz (registro contenente l'indirizzo della working zone corrente)
    process(i_clk,i_rst,end_reset)
        begin
        if(i_rst = '1' OR end_reset = '1') then
            o_regwz <= "00000000";
        elsif i_clk'event and i_clk = '1' then
            if(regwz_load = '1') then
                o_regwz <= i_data;
            end if;
        end if;
    end process;
    
    -- Analisi
    
    -- Enable reale di regsub
    regsub_enable <= regsub_load AND (NOT is_in);
    
    -- Controllo del registro contenente il valore di offset tra indirizzo e WZ per verificarne l'appartenenza
    process(i_clk,i_rst,end_reset)
       begin
        if(i_rst = '1' OR end_reset = '1') then
            o_regsub <= "00001000";
        elsif i_clk'event and i_clk = '1' then
            if(regsub_enable = '1') then
                o_regsub <= o_regin - o_regwz;
            end if;
        end if;
    end process;
     
    -- Valutazione dell'appertenenza dell'indirizzo da codificare a una wz
    is_in <= '1' when (o_regsub = "00000000" OR o_regsub = "00000001" OR o_regsub = "00000010" OR o_regsub = "00000011") else '0';

    -- Output

    -- Calcolo della codifica 1hot di sub (rete combinatoria)
    onehot <= (o_regsub(1) AND o_regsub(0)) & (o_regsub(1) AND NOT(o_regsub(0))) & (NOT(o_regsub(1)) AND o_regsub(0)) & (NOT(o_regsub(1)) AND NOT(o_regsub(0)));
    
    -- Calcolo della wz in analisi in regsub dato l'offset dovuto alla pipeline
    wzoff <= o_regnext(2 downto 0) - "011";
    
    -- Multiplexer di output
    with is_in select
        o_muxwz <= o_regin(6 downto 0) when '0',
        wzoff & onehot when '1',
            "XXXXXXX" when others;

    -- Valore di output
    o_data <= is_in & o_muxwz;
end Behavioral;
