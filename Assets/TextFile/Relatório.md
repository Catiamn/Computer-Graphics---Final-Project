
##

# Projecto Final de Computação Gráfica 
## Simulação de Deformação de Ambientes em Unity
---

## Introdução e Objetivo

Este projeto pretende estudar e implementar um sistema de deformação do terreno
que se adapta a diferentes ambientes e interage com movimento de uma personagem/objeto 
simples, recorrendo a *compute shaders*, HLSL shaders e scripts no Unity. Também iremos
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
- Limitações do GPU: A implementação com *compute shaders* requer uma gestão rigorosa de memória 
e sincronização entre buffers e texturas.
- Precisão das deformações: Ajustar a intensidade e o raio do rasto para obter um resultado visual
coerente sem exagerar a deformação.
- Artefactos visuais: Surgimento de irregularidades visuais, como bordas duras ou padrões repetitivos,
quando o noise não era corretamente parametrizado.
- Realismo vs Performance: Encontrar um equilíbrio entre a qualidade visual das deformações e o desempenho.

---

## Métodos escolhidos

Optamos por utilizar Deformação Procedural com um *Tessellation Shader*, o que nos permite manter um bom desempenho e deformações detalhadas, e um shader com Perlin Noise, para criar uma textura irregular na neve.
Poderiamos ter feito usando outros metódos ou através do CPU, porém esta técnica tem um melhor desempenho geral e é mais flexível.

Comparando os métodos que vamos utilizar com os métodos baseados exclusivamente em height maps, normal maps ou decals, 
esta abordagem que estamos a seguir oferece deformações reais na geometria e evita efeitos puramente visuais.

---

## Como procedemos

A nossa lógica de pensamento começou com o objetivo de distorcer os vertices,
para isso utilizamos um *compute shader*. Que é responsável por puxar os vertices para baixo ou para cima.
Depois desse shader, decidimos que tinhamos de ter algum tipo de textura para a neve,
que iria mudar as cores, escurecendo as zonas onde a neve iria ser deformada,
e iria criar também diversidade na textura. Para isso aplicamos um Perlin Noise num *texture shader* 
para criar as tais irregularidades necessárias. Essa textura iria ser aplicada depois do *compute shader*, e seria tileable.

Por fim adicionamos um *tessellation shader*, que irá ser juntado com o *texture shader*,
para que a nossa mesh tenha mais detalhes.

Tendo em conta tudo isto acabamos com quatro scripts e três shaders.

## Scripts e Shaders

O processo era para começar na criação do terreno atraves do script *PlaneMeshGen*, que seria reponsável por gerar a mesh base,
definindo os *UVS*, o *pivot* e a densidade inicial dos vertices e da mesh. 
Porém não conseguimos com que ele seja funcional, então acabamos por criar uma mesh manualmente no Unity com a densidade necessária.

De seguida, o script *DeformationController* é responsável por recolher as informações da mesh, como os vertices e dimensões, e comunica-las para o GPU e para o *MeshDeformation* *compute shader*.
É também neste script que definimos os parametros de deformação, como o raio e os limites máximos e mínimos.

Por último dos scripts temos o *ObjectControler* que é responsável por definir a posição de contacto com o terreno e o raio de influência do objeto/personagem.
Estes dados são continuamente atualizados e enviados para o *compute shader*, permitindo que a deformação seja dinâmica e responsiva ao movimento do objeto em tempo real.

Já em relação aos shaders, o *MeshDeformation* *compute shader*, que é executado no GPU, é reponsável por modificar diretamente a posição dos vertices da mesh, 
puxando-os para cima ou para baixo consoante a posição da personagem/objeto e o raio de influência definido.
Esta abordagem, como dito antes, explora o GPU de forma a processar grandes quantidades de vertices simultaneamente de forma eficiente.

Após a deformação da geometria base, temos o *TessellationShader*, que está integrado, juntamente com o *SnowShader*, no *SnowXTesselation*.
Este shader subdivide a mesh, aumentando a densidade dos triângulos para permitir deformações mais detalhadas e suaves. 
A tesselation é aplicada no GPU e melhora significamente a qualidade visual do terreno deformado, especialmente quando visto de perto.

Depois, temos o *Snowshader*, que trabalha com o componente visual do terreno.
Este shader aplica cores e texturs com base na altura da mesh. Ele utiliza parâmetros como *_TopColor* e *_BottomColor* e *Perlin Noise* para introduzir irregularidades visuais,
garantido que as zonas deformadas sejam bem integradas com o resto da neve.

Por fim, temos o *SnowXTesselation*, que combina o *TessellationShader* e o *SnowShader*.

---

### O que muderiamos

Nós também queriamos ter só aplicado o *tessellation* só nas zonas deformadas, de forma a melhorar o desempenho, idealmente só os vertices que fossem afetados pela deformação deveriam receber mais subdivisões.

Porém para isso teriamos de estar a modificar o *compute shader* para identificar essas zonas e visto que o *tessellation shader* é aplicado depois do *compute shader*, não coneguindo identificar os vertices que precisamo de detalhe,
ele só vê a geometria da mesh depois de ser modificada.

Também mudariamos o script *PlaneMeshGen* para que ele fosse funcional, de forma a criar a mesh base automaticamente, em vez de termos de criar manualmente no Unity.

---

## Conclusão

Para concluir, este projeto permitiu-nos explorar técnicas avançadas de computação gráfica, como o uso de *compute shaders* e *tessellation shaders*. 
O uso da *deformação procedural* também se revelou como superior a abordagens que fazem uso de *height maps* ou *decals*, uma vez que permite a modificação real da geometria da mesh.
Enquanto que, por exemplo, os height maps produzem apenas uma ilusão visual de profundidade.
Já o uso do *tessellation shader* que nos permite aumentar a densidade mesh apenas durante o processo de rendering, em comparação com uma criação inicial de uma mesh altamente detalhada,
o *tessellation* oferece maior flexibilidade e gestão de recursos. O facto de que este metódo tem zero dependência em heigh maps, dá-nos também um controlo maior na mesh que criamos.
Além disso, o facto que os metódos escolhidos são executados no GPU, torna-os mais eficientes do que metódos equivalentes implementadas no CPU.

De forma geral, o projeto conseguiu atingir os seus objetivos iniciais, demostrando que é possível criar um sistema de deformação de mesh eficiente e flexìvel, recorrendo maioritariamete ao processamento do GPU.

---
## Tutoriais e referências que ajudaram na implementação do projeto
https://www.youtube.com/watch?v=bT0D1uI_RNI - Interactive Snow Compute Shader - Unity

https://youtube.com/shorts/ub_TUpg63Jc?si=5xTkDRK9pof3RiTv - Snow Tracks Shorts - Unity

https://www.youtube.com/playlist?list=PL3POsQzaCw53KM74XVRXv2xyesLjngfbG - Snow Tracks PLaylist - Unity 

https://www.youtube.com/watch?v=z7kQpUZXXhw - Tracks in Snow - Unity



## Fontes
https://dl.acm.org/doi/pdf/10.1145/3402942.3402995 - Real-time Interactive Snow Simulation using Compute Shaders in
Digital Environments

https://www.diva-portal.org/smash/get/diva2:642292/FULLTEXT01.pdf - In-game Interaction with a
snowy landscape

https://diglib.eg.org/server/api/core/bitstreams/63c4eb5f-e09c-4cc7-8a12-d96f42a4cf9f/content - Snow and Ice Animation Methods in Computer Graphics


