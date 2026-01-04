
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

CENAS PARA MUDAR:
## #1 Obstáculo  – 



### Problemas encontrados



---

## #2 Obstáculo  – 


### Problemas encontrados


---

## Obstáculo 3 – 



### Problemas encontrados



---

## Obstáculo 4 – 


### Problemas encontrados


---

## Conclusão

---
## Tutoriais e referências que ajudaram na implementação do projeto
https://www.youtube.com/watch?v=bT0D1uI_RNI
https://youtube.com/shorts/ub_TUpg63Jc?si=5xTkDRK9pof3RiTv



## Fontes
https://dl.acm.org/doi/pdf/10.1145/3402942.3402995


