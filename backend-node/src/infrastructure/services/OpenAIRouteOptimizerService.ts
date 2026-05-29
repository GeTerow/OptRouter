import { zodResponseFormat } from 'openai/helpers/zod';
import { z } from 'zod';
import type { IOptimizationService } from '../../application/services/IOptimizationService.js';
import type { OptimizedRoute } from '../../domain/schemas/optimizeSchemas.js';
import { OptimizedRouteSchema } from '../../domain/schemas/optimizeSchemas.js';
import { openai } from '../lib/openai.js';

const routeStopSchema = z.object({
  name: z.string(),
  address: z.string(),
});

const openAIRouteSchema = z.object({
  totalTime: z.string(),
  totalDistance: z.string(),
  stops: z.array(routeStopSchema),
});

const DEFAULT_MODEL = 'gpt-4o-mini';

function buildMapsUrl(stops: OptimizedRoute['stops']) {
  if (stops.length === 0) {
    return 'https://www.google.com/maps';
  }

  const encodedStops = stops.map((stop) => encodeURIComponent(stop.address).replace(/%20/g, '+'));
  return `https://www.google.com/maps/dir/${encodedStops.join('/')}`;
}

export class OpenAIRouteOptimizerService implements IOptimizationService {
  async optimize(addresses: string[]): Promise<OptimizedRoute> {
    const model = process.env.OPENAI_ROUTE_OPTIMIZER_MODEL || DEFAULT_MODEL;

    const completion = await openai.chat.completions.parse({
      model,
      messages: [
        {
          role: 'system',
          content: [
            'Você é um otimizador de rotas para entregas urbanas no Brasil.',
            'Use conhecimento geográfico geral para ordenar os destinos quando a API do Google Maps falhar.',
            'Mantenha o primeiro endereço como origem e também como destino final.',
            'Reordene apenas os endereços intermediários para reduzir deslocamento provável.',
            'Não invente paradas novas. Só corrija ou normalize endereços quando houver erro óbvio de escrita.',
            'Retorne tempos e distâncias como estimativas textuais, prefixadas por "Estimado".',
          ].join(' '),
        },
        {
          role: 'user',
          content: `Otimize esta rota e retorne JSON no schema solicitado:\n${addresses
            .map((address, index) => `${index + 1}. ${address}`)
            .join('\n')}`,
        },
      ],
      response_format: zodResponseFormat(openAIRouteSchema, 'optimized_route'),
      temperature: 0.1,
      max_completion_tokens: 1200,
    });

    const parsed = completion.choices[0]?.message.parsed;

    if (!parsed) {
      throw new Error('A resposta da OpenAI para otimização da rota está vazia ou inválida.');
    }

    const stops = parsed.stops.map((stop, index) => ({
      name: stop.name || `Parada ${index + 1}`,
      address: stop.address,
    }));

    const route = {
      totalTime: parsed.totalTime,
      totalDistance: parsed.totalDistance,
      numberOfStops: stops.length,
      stops,
      mapsUrl: buildMapsUrl(stops),
    };

    const validation = OptimizedRouteSchema.safeParse(route);

    if (!validation.success) {
      throw new Error(`A resposta da OpenAI para otimização da rota é inválida: ${validation.error.message}`);
    }

    return validation.data;
  }
}
