import Image from "next/image";

export function FoodImage({
  alt,
  mealId,
  mealTitle,
  position = "50% 50%",
  priority = false,
  className = "",
  decorative = false,
}: {
  alt: string;
  mealId?: string;
  mealTitle?: string;
  position?: string;
  priority?: boolean;
  className?: string;
  decorative?: boolean;
}) {
  const mealImages: Record<string, string> = {
    "pesto-rigatoni": "/meal-pesto-rigatoni.png",
    "crispy-chicken-tacos": "/meal-crispy-chicken-tacos.png",
    "turkey-rice-bowls": "/meal-turkey-rice-bowls.png",
    "smoky-turkey-chili": "/meal-smoky-turkey-chili.png",
    "sausage-pepper-pan": "/meal-sausage-peppers.png",
    "turkey-tomato-rigatoni": "/meal-turkey-rigatoni.png",
    "bean-pepper-quesadillas": "/meal-black-bean-quesadillas.png",
  };
  const title = mealTitle?.toLowerCase() ?? "";
  const imageFromTitle = title.includes("pesto rigatoni") ? "/meal-pesto-rigatoni.png"
    : title.includes("chicken tacos") ? "/meal-crispy-chicken-tacos.png"
    : title.includes("turkey rice bowls") ? "/meal-turkey-rice-bowls.png"
    : title.includes("turkey") && title.includes("chili") ? "/meal-smoky-turkey-chili.png"
    : title.includes("sausage") && title.includes("peppers") ? "/meal-sausage-peppers.png"
    : title.includes("turkey rigatoni") ? "/meal-turkey-rigatoni.png"
    : title.includes("black bean") && title.includes("quesadilla") ? "/meal-black-bean-quesadillas.png"
    : undefined;

  return (
    <div className={`food-image ${className}`}>
      <Image
        src={imageFromTitle ?? (mealId ? mealImages[mealId] : undefined) ?? "/weektable-dinners.png"}
        alt={decorative ? "" : alt}
        fill
        priority={priority}
        sizes="(max-width: 768px) 100vw, 60vw"
        style={{ objectFit: "cover", objectPosition: position }}
      />
    </div>
  );
}
