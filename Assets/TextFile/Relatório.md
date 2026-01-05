
##

# Projecto Final de Computação Gráfica 
## Simulação de Deformação de Ambientes em Unity
---

## Introdução e Objetivo

Este projeto pretende estudar e implementar um sistema de deformação do terreno
que se adapta a diferentes ambientes e interage com movimento de uma personagem/objeto 
simples, recorrendo a compute shaders, HLSL shaders e scripts no Unity. Também iremos
utilizar o processamento do GPU para atualizar dinamicamente height maps que 
representam a deformação do terreno.

Esta abordagem permite simular profundidade e relevo sem necessidade de alterar 
diretamente a geometria da mesh, tornando o sistema mais eficiente e reutílizavel.

Como referencia inicial encontramos este video do *Reddit* que nos deu uma ideia de como proceder:
https://www.reddit.com/r/Unity3D/comments/a98dar/implemented_dynamic_tessellation_for_my_snow/ 

## Autoras

- **Cátia Nascimento** – a22404090 
- **Lisa Carvalho** – a22405414

---
## Métodos que poderiam ser utilizados
- **Height Maps**: imagens em escala de cinza que representam a elevação do terreno.
- **Deformação Procedural**: algoritmos que modificam a geometria do terreno com base em regras
- **Tessellation Shader**: shader que subdivide a mesh do terreno para permitir deformações mais detalhadas.
- **Displacement Mapping**: técnica que utiliza height maps para deslocar vértices da mesh.
- **Noise Functions**: utilização de funções de ruído (noise), como Perlin e Simplex, para gerar deformações naturais.
- **Bump Mapping**: técnica que simula detalhes de superfície, sem alterar a geometria, utilizando luz.

### Principais Problemas
- Gestão de desempenho: Atualizações frequentes do height map pode ter um impacto no desempenho,
exigindo cuidado na resolução das texturas e na frequência de atualizações.
- Limitações do GPU: A implementação com compute shaders requer uma gestão rigorosa de memória 
e sincronização entre buffers e texturas.
- Precisão das deformações: Ajustar a intensidade e o raio do rasto para obter um resultado visual
coerente sem exagerar a deformação.
- Artefactos visuais: Surgimento de irregularidades visuais, como bordas duras ou padrões repetitivos,
quando o noise não era corretamente parametrizado.
- Realismo vs Performance: Encontrar um equilíbrio entre a qualidade visual das deformações e o desempenho.

---

## Métodos escolhidos

Optamos por utilizar Deformação Procedural com um Tessellation Shader e um shader,o que nos permite manter um bom desempenho e deformações detalhadas, com Perlin Noise para criar uma textura irregular na neve.
Poderiamos ter feito usando outros metódos ou através do CPU, porém esta técnica tem um melhor desempenho geral e é mais flexível.

Comparando os métodos que vamos utilizar com os métodos baseados exclusivamente em height maps, normal maps ou decals, 
esta abordagem que estamos a seguir oferece deformações reais na geometria e evita efeitos puramente visuais.

---

## Como procedemos

A nossa lógica de pensamento começou com o objetivo de distorcer os vertices,
para isso utilizamos um compute shader. Que é responsável por puxar os vertices para baixo ou para cima.
Depois desse shader, decidimos que tinhamos de ter algum tipo de textura para a neve,
que iria mudar as cores, escurecendo as zonas onde a neve iria ser deformada,
e iria criar também diversidade na textura. Para isso aplicamos um Perlin Noise num texture shader 
para criar as tais irregularidades necessárias. Essa textura iria ser aplicada depois do compute shader, e será tileable.

Por fim adicionamos um tessellation shader, que irá ser juntado com o texture shader,
para que a nossa mesh tenha mais detalhes.



---

### Obstáculos

Nós também queriamos ter feito o tessellation só nas partes deformadas, de forma a melhorar o desempenho,
porém para isso teriamos de estar a modificar o compute shader para identificar essas zonas.
Visto que o tessellation shader é aplicado depois do compute shader, não coneguindo identificar os vertices que precisamo de detalhe,
ele só vê a geometria da mesh depois de ser modificada.



---

## Conclusão

---
## Tutoriais e referências que ajudaram na implementação do projeto
https://www.youtube.com/watch?v=bT0D1uI_RNI
https://youtube.com/shorts/ub_TUpg63Jc?si=5xTkDRK9pof3RiTv



## Fontes
https://dl.acm.org/doi/pdf/10.1145/3402942.3402995
https://www.diva-portal.org/smash/get/diva2:642292/FULLTEXT01.pdf
https://diglib.eg.org/server/api/core/bitstreams/63c4eb5f-e09c-4cc7-8a12-d96f42a4cf9f/content

