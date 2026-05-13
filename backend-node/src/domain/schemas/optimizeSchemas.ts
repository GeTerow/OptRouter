import { z } from 'zod';

export const OptimizeRouteRequestSchema = z.object({
  addresses: z.array(z.string().min(1, { message: 'O endereço não pode ser vazio.' })).min(2, {
    message: 'É necessário fornecer pelo menos 2 endereços (origem e um destino).',
  }),
});

export const OptimizedRouteSchema = z.object({
  totalTime: z.string(),
  totalDistance: z.string(),
  numberOfStops: z.number(),
  stops: z.array(
    z.object({
      name: z.string(),
      address: z.string(),
    })
  ),
  mapsUrl: z.string().url(),
});

export type OptimizedRoute = z.infer<typeof OptimizedRouteSchema>;